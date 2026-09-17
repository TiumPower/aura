# Một dòng biến động ví trả trước. Số dư luôn đọc từ `members.wallet_balance`,
# bảng này là sổ để đối chiếu — lệch nhau thì biết ngay ở đâu.
class WalletTransaction < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[topup bonus spend refund adjust].freeze
  KIND_LABELS = {
    "topup" => "Nạp ví", "bonus" => "Thưởng nạp ví", "spend" => "Chi từ ví",
    "refund" => "Hoàn vào ví", "adjust" => "Điều chỉnh"
  }.freeze

  belongs_to :workspace
  belongs_to :member
  belongs_to :order, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :amount, numericality: { other_than: 0 }

  scope :recent, -> { order(created_at: :desc) }

  def kind_label = KIND_LABELS[kind] || kind

  # Ghi một biến động ví và cập nhật số dư trong CÙNG transaction.
  def self.record!(member:, kind:, amount:, order: nil, note: nil, actor: nil)
    transaction do
      member.lock!
      new_balance = member.wallet_balance.to_i + amount.to_i
      raise ArgumentError, "Ví không đủ số dư" if new_balance.negative?
      member.update!(wallet_balance: new_balance)
      create!(workspace: member.workspace, member: member, order: order, kind: kind,
              amount: amount, balance_after: new_balance, note: note, actor_id: actor&.id)
    end
  end
end
