# Một dịch vụ trên menu. Đây là bản ghi engine xếp lịch đọc: dịch vụ này chiếm
# phòng loại nào, bao lâu, có cần KTV không và cần mấy người.
class Service < ApplicationRecord
  acts_as_tenant(:workspace)
  extend FriendlyId
  friendly_id :name, use: [:slugged, :scoped], scope: :workspace

  belongs_to :workspace
  belongs_to :service_category, optional: true
  has_many :service_variants, dependent: :destroy
  has_many :service_prices,   dependent: :destroy
  has_many :staff_services,   dependent: :destroy
  has_many :staff_members, through: :staff_services
  has_many :booking_items, dependent: :restrict_with_error
  has_one_attached :photo

  validates :name, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :price, :cost, numericality: { greater_than_or_equal_to: 0 }
  validates :staff_count, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered,  -> { order(:position, :name) }
  scope :active,   -> { where(active: true) }
  scope :bookable, -> { active.where(online_bookable: true, is_addon: false) }
  scope :addons,   -> { active.where(is_addon: true) }
  scope :main,     -> { where(is_addon: false) }
  scope :in_category, ->(id) { id.present? ? where(service_category_id: id) : all }

  # Loại phòng dịch vụ này chạy được. Rỗng = phòng nào cũng được.
  def allowed_room_type_ids = Array(room_type_ids).map(&:to_i)

  def any_room? = allowed_room_type_ids.empty?

  def accepts_room?(room)
    return false unless requires_room?
    any_room? || allowed_room_type_ids.include?(room.room_type_id)
  end

  # Thời gian dọn phòng sau lượt này: khai riêng ở dịch vụ → của phòng → tham số.
  def buffer_for(room = nil)
    buffer_minutes.presence || room&.turnaround ||
      workspace.setting_i("default_turnaround_minutes")
  end

  # Giá và thời lượng của một biến thể (hoặc của chính dịch vụ khi không chọn).
  def duration_for(variant = nil) = (variant&.duration_minutes || duration_minutes).to_i

  def price_for(variant = nil, branch: nil)
    if branch
      row = service_prices.find { |p| p.branch_id == branch.id && p.service_variant_id == variant&.id }
      return row.price if row
    end
    (variant&.price.presence || price).to_i
  end

  def price_label = "#{ActiveSupport::NumberHelper.number_to_delimited(price)}đ"

  def duration_label
    d = duration_minutes.to_i
    d >= 60 && (d % 60).zero? ? "#{d / 60}h" : "#{d}′"
  end

  # Nhãn hiện cho khách: "60′ · 450.000đ" hoặc danh sách biến thể.
  def variant_options(branch: nil)
    rows = service_variants.select(&:active?).sort_by(&:position)
    return [[nil, duration_minutes, price_for(nil, branch: branch)]] if rows.empty?
    rows.map { |v| [v, v.duration_minutes, price_for(v, branch: branch)] }
  end

  # KTV làm được dịch vụ này. KHÔNG khai kỹ năng = mọi KTV đều làm được: spa nhỏ
  # không việc gì phải khai ma trận kỹ năng trước khi nhận khách đầu tiên.
  def capable_staff_ids
    ids = staff_services.pluck(:staff_member_id)
    ids.presence
  end

  def commission_rate_for(staff)
    commission_percent.presence || staff&.commission_rate ||
      workspace.setting_i("commission_default_percent")
  end
end
