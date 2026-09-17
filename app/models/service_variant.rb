# Biến thể thời lượng/giá của một dịch vụ: 60′ / 90′ / 120′.
class ServiceVariant < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :service

  validates :name, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :duration_minutes) }
  scope :active,  -> { where(active: true) }

  def active? = active
  def label = "#{name} · #{ActiveSupport::NumberHelper.number_to_delimited(price)}đ"

  # Tên biến thể thường CHÍNH LÀ thời lượng ("90′"), nên view nào nối thêm
  # thời lượng vào sau tên đều ra "90′ · 90′". Nối ở một chỗ duy nhất, và chỉ
  # nối khi tên không tự nói lên thời lượng.
  def duration_label
    return name if name.to_s.include?(duration_minutes.to_s)
    "#{name} · #{duration_minutes}′"
  end
end
