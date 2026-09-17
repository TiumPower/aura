# Loại phòng do từng spa tự định nghĩa: "Phòng đơn", "Phòng đôi", "Khu foot",
# "Phòng xông hơi", "Giường gội"… Dịch vụ khai mình chạy được ở loại nào.
class RoomType < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  has_many :rooms, dependent: :nullify

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_]+\z/ }

  scope :ordered, -> { order(:position, :name) }

  before_validation :default_key, on: :create

  # Bộ loại phòng gợi ý theo loại hình — spa sửa lại tuỳ ý sau khi tạo.
  PRESETS = {
    "massage" => [
      { key: "foot",   name: "Khu foot massage", default_capacity: 4, icon: "🦶" },
      { key: "single", name: "Phòng massage đơn", default_capacity: 1, icon: "🛏️" },
      { key: "couple", name: "Phòng đôi",         default_capacity: 2, icon: "👫" },
      { key: "vip",    name: "Phòng VIP",         default_capacity: 2, icon: "⭐" },
      { key: "sauna",  name: "Xông hơi / jacuzzi", default_capacity: 6, icon: "♨️" }
    ],
    "beauty" => [
      { key: "facial",  name: "Phòng chăm sóc da", default_capacity: 1, icon: "🧖" },
      { key: "body",    name: "Phòng body",        default_capacity: 1, icon: "🛏️" },
      { key: "laser",   name: "Phòng máy / laser", default_capacity: 1, icon: "💡" },
      { key: "nail",    name: "Khu nail / gội",    default_capacity: 3, icon: "💅" },
      { key: "consult", name: "Phòng tư vấn",      default_capacity: 1, icon: "💬" }
    ]
  }.freeze

  def self.presets_for(business_type)
    case business_type
    when "massage" then PRESETS["massage"]
    when "beauty"  then PRESETS["beauty"]
    else PRESETS["massage"] + PRESETS["beauty"]
    end
  end

  def display_name = [icon.presence, name].compact.join(" ")

  private

  def default_key
    self.key ||= name.to_s.parameterize(separator: "_").presence || SecureRandom.hex(3)
  end
end
