# Hạng KTV. Ở VN rất phổ biến việc khách chọn KTV hạng cao và trả phụ thu —
# `surcharge` là số tiền cộng thêm vào mỗi lượt dịch vụ của hạng đó.
class StaffLevel < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  has_many :staff_members, dependent: :nullify

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :workspace_id }

  scope :ordered, -> { order(:position, :name) }

  before_validation :default_key, on: :create

  PRESETS = [
    { key: "standard", name: "Tiêu chuẩn", surcharge: 0,      position: 0 },
    { key: "senior",   name: "Cao cấp",    surcharge: 50_000, position: 1 },
    { key: "master",   name: "Chuyên gia", surcharge: 100_000, position: 2 }
  ].freeze

  def surcharge_label = surcharge.to_i.zero? ? "Không phụ thu" : "+#{ActiveSupport::NumberHelper.number_to_delimited(surcharge)}đ"

  private

  def default_key
    self.key ||= name.to_s.parameterize(separator: "_").presence || SecureRandom.hex(3)
  end
end
