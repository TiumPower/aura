# Gói thuê bao nền tảng. Giá theo quy mô (số cơ sở / KTV / phòng); AI đi kèm
# mọi gói, không đếm theo lượt.
class Plan < ApplicationRecord
  validates :key, :name, presence: true
  validates :key, uniqueness: true

  scope :ordered, -> { order(:position, :price) }

  DEFAULTS = [
    { key: "starter", name: "Starter", price: 299_000, position: 0,
      max_branches: 1, max_staff: 8, max_rooms: 8,
      allow_custom_domain: false, allow_multi_branch: false, allow_packages: true,
      allow_commissions: true, allow_inventory: false, allow_ai: true,
      features: ["1 cơ sở", "Tối đa 8 nhân sự", "8 phòng/giường", "Đặt lịch online + PWA khách",
                 "Thu ngân & thẻ liệu trình", "Hoa hồng KTV"] },
    { key: "pro", name: "Pro", price: 699_000, position: 1,
      max_branches: 3, max_staff: 30, max_rooms: 40,
      allow_custom_domain: false, allow_multi_branch: true, allow_packages: true,
      allow_commissions: true, allow_inventory: true, allow_ai: true,
      features: ["3 cơ sở", "30 nhân sự", "Kho & vật tư tiêu hao", "Hồ sơ điều trị + ảnh tiến trình",
                 "Báo cáo hiệu suất phòng & KTV", "Chat, thông báo, đánh giá"] },
    { key: "business", name: "Business", price: 1_490_000, position: 2,
      max_branches: nil, max_staff: nil, max_rooms: nil,
      allow_custom_domain: true, allow_multi_branch: true, allow_packages: true,
      allow_commissions: true, allow_inventory: true, allow_ai: true,
      features: ["Không giới hạn cơ sở / nhân sự", "Tên miền riêng", "Tách số liệu theo cơ sở",
                 "Ưu tiên hỗ trợ & đào tạo"] }
  ].freeze

  def self.lowest_allowing(feature)
    col = "allow_#{feature}"
    return nil unless column_names.include?(col)
    ordered.detect { |p| p.public_send(col) }
  end

  def self.for(key)
    find_by(key: key) || new(DEFAULTS.find { |d| d[:key] == key } || DEFAULTS.first)
  end

  def self.seed_defaults!
    DEFAULTS.each do |attrs|
      plan = find_or_initialize_by(key: attrs[:key])
      plan.assign_attributes(attrs)
      plan.save!
    end
  end

  def unlimited_branches? = max_branches.nil?
  def unlimited_staff?    = max_staff.nil?
  def price_label = "#{ActiveSupport::NumberHelper.number_to_delimited(price)}đ"

  def localized_features
    vals = I18n.t("merchant.plans.#{key}.features", default: nil)
    vals.is_a?(Array) ? vals : features
  end
end
