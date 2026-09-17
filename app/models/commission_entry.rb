# Một dòng hoa hồng. Sinh ra khi bill đóng, nên bảng lương chỉ là phép cộng —
# không ai phải tính tay và không có chỗ để tranh luận.
class CommissionEntry < ApplicationRecord
  acts_as_tenant(:workspace)

  ROLES = { "therapist" => "KTV làm dịch vụ", "consultant" => "Tư vấn chốt thẻ" }.freeze
  STATUSES = %w[pending approved paid].freeze
  STATUS_LABELS = { "pending" => "Chờ chốt", "approved" => "Đã chốt", "paid" => "Đã trả" }.freeze

  belongs_to :workspace
  belongs_to :staff_member
  belongs_to :order, optional: true
  belongs_to :order_item, optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :in_range, ->(from, to) { where(earned_on: from..to) }
  scope :recent, -> { order(earned_on: :desc, created_at: :desc) }

  def role_label = ROLES[role] || role
  def status_label = STATUS_LABELS[status] || status
  def tip? = basis == "tip"
end
