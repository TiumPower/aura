# Phòng hoặc khu phục vụ. `capacity` là số khách phục vụ ĐỒNG THỜI: phòng đơn
# là 1, khu foot 4 ghế là 4. Engine xếp lịch đếm số lượt trùng giờ < capacity.
class Room < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[active maintenance inactive].freeze
  STATUS_LABELS = { "active" => "Sẵn sàng", "maintenance" => "Đang bảo trì", "inactive" => "Không dùng" }.freeze

  belongs_to :workspace
  belongs_to :branch
  belongs_to :room_type, optional: true
  has_many :booking_items, dependent: :nullify

  validates :name, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }

  scope :active,  -> { where(status: "active") }
  scope :ordered, -> { order(:position, :name) }
  scope :bookable, -> { active.where(online_bookable: true) }
  scope :of_type, ->(type_id) { where(room_type_id: type_id) if type_id.present? }

  def active? = status == "active"
  def status_label = STATUS_LABELS[status] || status
  def display_name = [code.presence, name].compact.join(" · ")
  def type_name = room_type&.name

  # Thời gian dọn phòng: phòng khai riêng thì dùng của phòng, không thì lấy
  # tham số của chi nhánh.
  def turnaround
    turnaround_minutes.presence || branch.setting_i("default_turnaround_minutes")
  end
end
