# Bill spa thu của KHÁCH. (Đừng lẫn với `Invoice` — đó là hoá đơn thuê bao nền
# tảng thu của spa.) Một bill mở khi khách bắt đầu và đóng khi thu đủ tiền.
class Order < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[open paid void refunded].freeze
  STATUS_LABELS = { "open" => "Đang mở", "paid" => "Đã thu", "void" => "Đã huỷ", "refunded" => "Đã hoàn" }.freeze

  belongs_to :workspace
  belongs_to :branch
  belongs_to :member, optional: true
  belongs_to :booking, optional: true
  belongs_to :cashier, class_name: "User", optional: true
  has_many :order_items, dependent: :destroy
  has_many :order_payments, dependent: :destroy
  has_many :commission_entries, dependent: :nullify

  validates :code, presence: true, uniqueness: { scope: :workspace_id }
  validates :status, inclusion: { in: STATUSES }

  before_validation :assign_code, on: :create

  scope :open,   -> { where(status: "open") }
  scope :paid,   -> { where(status: "paid") }
  scope :recent, -> { order(created_at: :desc) }
  scope :closed_between, ->(from, to) { where(closed_at: from..to) }
  scope :at_branch, ->(id) { id.present? ? where(branch_id: id) : all }

  def open?      = status == "open"
  def paid?      = status == "paid"
  def voided?    = status == "void"
  def status_label = STATUS_LABELS[status] || status
  def customer_name = member&.display_name.presence || booking&.customer_name.presence || "Khách lẻ"
  def due = [total.to_i - paid_total.to_i, 0].max
  def overpaid = [paid_total.to_i - total.to_i, 0].max
  def settled? = due.zero?

  # Tính lại toàn bộ con số của bill. Đây là nguồn duy nhất — không màn hình nào
  # được tự cộng tay, nếu không hai chỗ sẽ ra hai số.
  def recalculate!
    items = order_items.to_a
    sub = items.reject { |i| i.kind == "tip" }.sum(&:total)
    tips = items.select { |i| i.kind == "tip" }.sum(&:total)
    disc = items.sum(&:discount_amount)

    sc_percent  = branch.setting_i("service_charge_percent")
    vat_percent = branch.setting_i("vat_percent")
    charge = sc_percent.positive? ? (sub * sc_percent / 100.0).round : 0
    # Giá niêm yết đã gồm VAT thì VAT chỉ là thông tin tách ra, không cộng thêm.
    vat = if vat_percent.zero?
      0
    elsif branch.setting?("price_includes_vat")
      ((sub + charge) - (sub + charge) / (1 + vat_percent / 100.0)).round
    else
      ((sub + charge) * vat_percent / 100.0).round
    end

    gross = sub + charge + tips
    gross += vat unless branch.setting?("price_includes_vat")
    rounding = branch.setting_i("rounding")
    gross = (gross.to_f / rounding).round * rounding if rounding > 1

    update!(subtotal: sub, discount_total: disc, service_charge: charge,
            vat_total: vat, tip_total: tips, total: gross,
            paid_total: order_payments.sum(:amount))
  end

  # `subtotal` cộng từ `order_items.total`, mà `total` của từng dòng ĐÃ trừ giảm
  # giá. Nên màn hình in "Tạm tính 360.000 / Giảm giá −40.000 / Khách trả
  # 360.000" — dãy số không cộng ra được và lễ tân không giải thích nổi với
  # khách. Chuỗi hiển thị phải bắt đầu từ giá gốc.
  def subtotal_before_discount = subtotal.to_i + discount_total.to_i

  def payment_summary
    order_payments.group(:method).sum(:amount)
  end

  private

  def assign_code
    return if code.present?
    date = Time.current.strftime("%y%m%d")
    seq = Order.unscoped.where(workspace_id: workspace_id).where("code LIKE ?", "#{date}%").count + 1
    self.code = format("%s-%03d", date, seq)
  end
end
