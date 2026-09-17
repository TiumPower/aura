# Định nghĩa một gói/thẻ để bán:
#   session_pack — n buổi dịch vụ (thẻ liệu trình kinh điển)
#   value_card   — thẻ tiền: nạp 5tr dùng được 6tr
#   membership   — thẻ thành viên theo kỳ
class Package < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[session_pack value_card membership].freeze
  KIND_LABELS = {
    "session_pack" => "Thẻ liệu trình (n buổi)",
    "value_card"   => "Thẻ tiền (nạp trước)",
    "membership"   => "Thẻ thành viên theo kỳ"
  }.freeze

  belongs_to :workspace
  has_many :package_lines, dependent: :destroy
  has_many :services, through: :package_lines
  has_many :member_packages, dependent: :nullify
  accepts_nested_attributes_for :package_lines, allow_destroy: true

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :name) }
  scope :active,  -> { where(active: true) }
  scope :sellable_online, -> { active.where(online_sellable: true) }

  def kind_label = KIND_LABELS[kind] || kind
  def session_pack? = kind == "session_pack"
  def value_card?   = kind == "value_card"

  def total_sessions = package_lines.sum(&:sessions)

  def validity = validity_days.presence || workspace.setting_i("package_validity_days")

  # Giá trị dùng được so với giá bán — con số bán thẻ dễ nhất.
  def face = value_card? ? (face_value.presence || price) : list_value

  def list_value
    package_lines.sum { |l| l.sessions * l.unit_price }
  end

  def savings = [face - price, 0].max

  def commission_rate
    commission_percent.presence || workspace.setting_i("commission_on_package_sale_percent")
  end
end
