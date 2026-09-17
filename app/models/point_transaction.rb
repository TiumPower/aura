# Một dòng biến động điểm thưởng.
class PointTransaction < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[earn redeem expire adjust].freeze
  KIND_LABELS = { "earn" => "Tích điểm", "redeem" => "Đổi điểm", "expire" => "Điểm hết hạn", "adjust" => "Điều chỉnh" }.freeze

  belongs_to :workspace
  belongs_to :member
  belongs_to :order, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :points, numericality: { other_than: 0 }

  scope :recent, -> { order(created_at: :desc) }

  def kind_label = KIND_LABELS[kind] || kind

  def self.record!(member:, kind:, points:, order: nil, note: nil, actor: nil)
    transaction do
      member.lock!
      balance = member.points_balance.to_i + points.to_i
      raise ArgumentError, "Không đủ điểm" if balance.negative?
      member.update!(points_balance: balance)
      months = member.workspace.setting_i("points_expiry_months")
      create!(workspace: member.workspace, member: member, order: order, kind: kind,
              points: points, balance_after: balance, note: note, actor_id: actor&.id,
              expires_on: (kind == "earn" && months.positive? ? months.months.from_now : nil))
    end
  end
end
