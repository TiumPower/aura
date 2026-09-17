# Nhóm dịch vụ trên menu: "Massage trị liệu", "Chăm sóc da", "Gói combo"…
class ServiceCategory < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  has_many :services, dependent: :nullify

  validates :name, presence: true

  scope :ordered, -> { order(:position, :name) }
  scope :active,  -> { where(active: true) }

  PRESETS = {
    "massage" => [
      { name: "Massage body",   icon: "💆" },
      { name: "Foot massage",   icon: "🦶" },
      { name: "Trị liệu",       icon: "🩺" },
      { name: "Xông hơi & jacuzzi", icon: "♨️" },
      { name: "Gói combo",      icon: "🎁" }
    ],
    "beauty" => [
      { name: "Chăm sóc da",    icon: "🧖" },
      { name: "Trị liệu da",    icon: "✨" },
      { name: "Triệt lông",     icon: "💡" },
      { name: "Chăm sóc cơ thể", icon: "🛀" },
      { name: "Gội & nail",     icon: "💅" }
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
end
