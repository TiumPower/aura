# Một dòng trên bill. `staff_member_id` là KTV thực hiện (để tính hoa hồng làm
# dịch vụ) và `consultant_id` là người chốt thẻ (hoa hồng tư vấn) — hai vai này
# khác nhau và thường là hai người khác nhau.
class OrderItem < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[service addon package topup product fee tip].freeze
  KIND_LABELS = {
    "service" => "Dịch vụ", "addon" => "Dịch vụ thêm", "package" => "Thẻ liệu trình",
    "topup" => "Nạp ví", "product" => "Hàng bán lẻ", "fee" => "Phụ phí", "tip" => "Tip cho KTV"
  }.freeze

  belongs_to :workspace
  belongs_to :order
  belongs_to :service, optional: true
  belongs_to :package, optional: true
  belongs_to :booking_item, optional: true
  belongs_to :staff_member, optional: true
  belongs_to :consultant, class_name: "StaffMember", optional: true
  belongs_to :package_credit, optional: true

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }

  before_save :compute_total

  def kind_label = KIND_LABELS[kind] || kind
  # Dòng được trả bằng buổi trong thẻ: tiền = 0 nhưng vẫn phải hiện trên bill,
  # nếu không khách sẽ tưởng spa quên trừ buổi.
  def from_package? = package_credit_id.present?

  # Giá trước giảm. `total` đã trừ giảm giá, nên biên lai in `total` ở cột dịch
  # vụ rồi in "Tạm tính" là giá gốc thì cột không cộng ra được dòng ngay dưới nó.
  def gross_total = from_package? ? 0 : unit_price.to_i * quantity.to_i

  private

  def compute_total
    self.total = if from_package?
      0
    else
      (unit_price.to_i * quantity.to_i) - discount_amount.to_i
    end
  end
end
