# Một lần thu tiền. Một bill có thể thu nhiều lần, nhiều phương thức (nửa tiền
# mặt nửa chuyển khoản là chuyện bình thường ở spa).
class OrderPayment < ApplicationRecord
  acts_as_tenant(:workspace)

  METHODS = %w[cash card transfer vietqr wallet package points other].freeze
  METHOD_LABELS = {
    "cash" => "Tiền mặt", "card" => "Thẻ (POS)", "transfer" => "Chuyển khoản",
    "vietqr" => "VietQR", "wallet" => "Ví trả trước", "package" => "Trừ buổi trong thẻ",
    "points" => "Đổi điểm", "other" => "Khác"
  }.freeze
  METHOD_ICONS = {
    "cash" => "💵", "card" => "💳", "transfer" => "🏦", "vietqr" => "📱",
    "wallet" => "👛", "package" => "🎟️", "points" => "⭐", "other" => "•"
  }.freeze

  belongs_to :workspace
  belongs_to :order
  belongs_to :received_by, class_name: "User", optional: true

  validates :method, inclusion: { in: METHODS }
  validates :amount, numericality: { other_than: 0 }

  before_validation { self.received_at ||= Time.current }

  scope :recent, -> { order(received_at: :desc) }

  def method_label = METHOD_LABELS[method] || method
  def method_icon  = METHOD_ICONS[method] || "•"
end
