# Một lượt chiếm phòng (và thường là một KTV) trong một khoảng giờ.
# `buffer_minutes` là thời gian dọn phòng SAU lượt này — phòng vẫn bị khoá
# trong khoảng đó, nên engine phải cộng nó khi kiểm tra trùng.
class BookingItem < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[planned in_progress done cancelled].freeze
  STATUS_LABELS = { "planned" => "Chờ làm", "in_progress" => "Đang làm",
                    "done" => "Xong", "cancelled" => "Đã huỷ" }.freeze

  belongs_to :workspace
  belongs_to :booking
  belongs_to :service
  belongs_to :service_variant, optional: true
  belongs_to :staff_member, optional: true
  belongs_to :room, optional: true
  belongs_to :parent_item, class_name: "BookingItem", optional: true
  has_many :addons, class_name: "BookingItem", foreign_key: :parent_item_id, dependent: :nullify

  validates :starts_at, :ends_at, :duration_minutes, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :live,    -> { where.not(status: "cancelled") }
  scope :ordered, -> { order(:starts_at, :position) }

  # Các lượt chiếm một PHÒNG trong khoảng [from, to). Tính cả thời gian dọn
  # phòng của lượt trước, nếu không thì khách sau bước vào lúc phòng chưa dọn.
  scope :room_busy, ->(room_id, from, to) {
    live.where(room_id: room_id)
        .where("booking_items.starts_at < :to AND (booking_items.ends_at + (booking_items.buffer_minutes * interval '1 minute')) > :from",
               from: from, to: to)
  }

  # Các lượt chiếm một KTV trong khoảng [from, to).
  scope :staff_busy, ->(staff_id, from, to) {
    live.where(staff_member_id: staff_id)
        .where("booking_items.starts_at < :to AND booking_items.ends_at > :from", from: from, to: to)
  }

  def status_label = STATUS_LABELS[status] || status
  def cancelled? = status == "cancelled"

  def service_label
    base = service.name
    service_variant ? "#{base} #{service_variant.name}" : base
  end

  def total = price.to_i + staff_surcharge.to_i - discount_amount.to_i
  def time_label = "#{starts_at.strftime('%H:%M')}–#{ends_at.strftime('%H:%M')}"
  def blocked_until = ends_at + buffer_minutes.to_i.minutes
end
