# Chi phí vận hành (tiền ra). Ghép với doanh thu để ra lãi thật, thay vì chỉ
# nhìn doanh thu.
class Expense < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :branch, optional: true

  CATEGORIES = %w[rent payroll supplies utility marketing equipment tax training other].freeze
  CATEGORY_LABELS = {
    "rent"      => "Thuê mặt bằng",
    "payroll"   => "Lương & hoa hồng",
    "supplies"  => "Vật tư, tinh dầu, khăn",
    "utility"   => "Điện, nước, internet",
    "marketing" => "Quảng cáo & khuyến mãi",
    "equipment" => "Máy móc, giường, sửa chữa",
    "tax"       => "Thuế & phí",
    "training"  => "Đào tạo KTV",
    "other"     => "Khác"
  }.freeze

  CATEGORY_ICONS = {
    "rent" => "🏠", "payroll" => "👥", "supplies" => "🧴", "utility" => "💡",
    "marketing" => "📣", "equipment" => "🛠️", "tax" => "🧾", "training" => "🎓", "other" => "•"
  }.freeze

  validates :amount, numericality: { greater_than: 0 }
  validates :spent_on, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :recent, -> { order(spent_on: :desc, created_at: :desc) }
  scope :in_range, ->(from, to) { where(spent_on: from..to) }
  scope :at_branch, ->(id) { id.present? ? where(branch_id: id) : all }

  def category_label = CATEGORY_LABELS[category] || category
  def category_icon  = CATEGORY_ICONS[category] || "•"
end
