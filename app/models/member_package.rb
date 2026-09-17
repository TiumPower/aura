# Thẻ một khách đã mua. Số buổi còn lại nằm ở `package_credits`; mỗi lần trừ
# buổi để lại dấu ở `package_credit_uses` — tranh chấp "sao hết buổi rồi" là
# chuyện thường xuyên nhất giữa spa và khách.
class MemberPackage < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[active used_up expired frozen refunded].freeze
  STATUS_LABELS = {
    "active" => "Đang dùng", "used_up" => "Đã dùng hết", "expired" => "Hết hạn",
    "frozen" => "Đang tạm dừng", "refunded" => "Đã hoàn tiền"
  }.freeze

  belongs_to :workspace
  belongs_to :member
  belongs_to :package, optional: true
  belongs_to :order, optional: true
  belongs_to :sold_by, class_name: "StaffMember", optional: true
  has_many :package_credits, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :purchased_on, presence: true

  scope :active,  -> { where(status: "active") }
  scope :usable,  -> { active.where("expires_on IS NULL OR expires_on >= ?", Date.current) }
  scope :recent,  -> { order(purchased_on: :desc, created_at: :desc) }
  scope :expiring_within, ->(days) {
    active.where(expires_on: Date.current..(Date.current + days))
  }

  def status_label = STATUS_LABELS[status] || status
  def value_card? = kind == "value_card"
  def expired? = expires_on.present? && expires_on < Date.current
  def usable? = status == "active" && !expired?

  def sessions_left = package_credits.sum { |c| c.remaining }
  def sessions_total = package_credits.sum(&:total_sessions)

  def days_left
    return nil if expires_on.nil?
    (expires_on - Date.current).to_i
  end

  # Thẻ còn ít buổi / sắp hết hạn — hai tín hiệu để nhắc khách gia hạn.
  def low_on_sessions?
    return false if value_card?
    sessions_left.positive? && sessions_left <= workspace.setting_i("low_sessions_threshold")
  end

  def expiring_soon?
    d = days_left
    d.present? && d >= 0 && d <= workspace.setting_i("package_expiry_warning_days")
  end

  # Buổi còn dùng được cho một dịch vụ (khớp cả biến thể nếu thẻ khai biến thể).
  def credit_for(service, variant = nil)
    return nil unless usable?
    rows = package_credits.select { |c| c.service_id == service.id && c.remaining.positive? }
    rows.find { |c| c.service_variant_id == variant&.id } || rows.first
  end

  def refresh_status!
    return if %w[refunded frozen].include?(status)
    if expired?
      update!(status: "expired")
    elsif !value_card? && sessions_total.positive? && sessions_left.zero?
      update!(status: "used_up")
    elsif value_card? && value_balance.to_i <= 0
      update!(status: "used_up")
    end
  end
end
