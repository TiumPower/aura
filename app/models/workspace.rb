# Một workspace = một thương hiệu spa (tenant). Tất cả dữ liệu nghiệp vụ mang
# workspace_id; mỗi workspace có subdomain riêng, tuỳ chọn tên miền riêng, bộ
# màu/chữ riêng, bộ module riêng và bộ tham số nghiệp vụ riêng.
class Workspace < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  include BusinessSettings

  STATUSES = %w[pending trial active past_due suspended].freeze
  STATUS_LABELS = {
    "pending" => "Chờ duyệt", "trial" => "Dùng thử", "active" => "Đang hoạt động",
    "past_due" => "Quá hạn", "suspended" => "Tạm ngưng"
  }.freeze
  PLANS = %w[starter pro business].freeze

  BUSINESS_TYPES = %w[massage beauty mixed].freeze
  BUSINESS_TYPE_LABELS = {
    "massage" => "Massage / foot massage / thư giãn",
    "beauty"  => "Spa thẩm mỹ / chăm sóc da",
    "mixed"   => "Kết hợp cả hai"
  }.freeze

  has_one_attached :logo
  has_one_attached :cover
  has_one_attached :static_qr # QR MoMo/ZaloPay của spa — không có thì rơi về VietQR

  # ---- Quan hệ ----------------------------------------------------------
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :branches, dependent: :destroy
  has_many :branch_hours, dependent: :destroy
  has_many :branch_closures, dependent: :destroy
  has_many :room_types, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :staff_levels, dependent: :destroy
  has_many :staff_members, dependent: :destroy
  has_many :staff_shifts, dependent: :destroy
  has_many :shift_templates, dependent: :destroy
  has_many :member_tiers, dependent: :destroy
  has_many :members, dependent: :destroy
  has_many :service_categories, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :service_variants, dependent: :destroy
  has_many :staff_services, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :booking_items, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :broadcasts, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :invoices, dependent: :destroy

  validates :name, :subdomain, presence: true
  validates :subdomain, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :business_type, inclusion: { in: BUSINESS_TYPES }

  before_validation :default_subdomain, on: :create

  # ---- Trạng thái -------------------------------------------------------
  def active?  = status == "active"
  def trial?   = status == "trial"
  def pending? = status == "pending"
  def onboarded? = settings["onboarded"] == true
  def status_label = STATUS_LABELS[status]
  def business_type_label = BUSINESS_TYPE_LABELS[business_type]

  def default_locale_sym
    %w[vi en].include?(locale_default) ? locale_default.to_sym : :vi
  end

  TRIAL_DAYS = 14

  def start_trial!(days = TRIAL_DAYS)
    update!(status: "trial", paid_until: days.days.from_now)
  end

  # Mọi spa cần ít nhất một chi nhánh — phòng, KTV và lịch đều treo vào đó.
  def ensure_default_branch!
    ActsAsTenant.with_tenant(self) do
      branches.first || branches.create!(name: "Cơ sở chính", city: branding_value("city"))
    end
  end

  def main_branch = ActsAsTenant.with_tenant(self) { branches.active.ordered.first }

  # ---- Gói thuê bao (giới hạn & cổng tính năng) -------------------------
  def plan_record
    @plan_record ||= Plan.for(plan)
  end

  def monthly_price = active? ? plan_record.price.to_i : 0

  # Dùng thử mở hết tính năng, bỏ mọi giới hạn.
  def full_access? = trial?

  def plan_allows?(feature)
    return true if full_access?
    case feature.to_sym
    when :custom_domain then plan_record.allow_custom_domain
    when :multi_branch  then plan_record.allow_multi_branch
    when :packages      then plan_record.allow_packages
    when :commissions   then plan_record.allow_commissions
    when :inventory     then plan_record.allow_inventory
    when :ai            then plan_record.allow_ai
    else true
    end
  end

  # Một tính năng chỉ chạy khi GÓI cho phép và spa đã BẬT module đó.
  def feature?(key)
    plan_allows?(key) && module?(key)
  end

  def branch_limit = full_access? ? nil : plan_record.max_branches
  def staff_limit  = full_access? ? nil : plan_record.max_staff
  def room_limit   = full_access? ? nil : plan_record.max_rooms

  def can_add_branch?(current = nil)
    within_limit?(branch_limit, current) { branches.count }
  end

  def can_add_staff?(current = nil)
    within_limit?(staff_limit, current) { staff_members.where(status: "active").count }
  end

  def can_add_room?(current = nil)
    within_limit?(room_limit, current) { rooms.count }
  end

  # ---- Thuê bao / thanh toán nền tảng -----------------------------------
  GRACE_DAYS = 10

  def subscription_active? = paid_until.present? && paid_until >= Time.current

  def subscription_days_left
    return nil if paid_until.nil?
    ((paid_until - Time.current) / 1.day).ceil
  end

  def subscription_overdue_days
    return nil if paid_until.nil? || subscription_active?
    ((Time.current - paid_until) / 1.day).floor
  end

  def payment_state
    return :suspended if status == "suspended" && !auto_suspended?
    return :trial     if trial? && subscription_active?
    return :paid      if subscription_active?
    return :owing     if paid_until.present?
    :new
  end

  PAYMENT_STATES = %i[paid trial owing suspended new].freeze
  PAYMENT_LABELS = {
    paid: "Đã thanh toán", trial: "Dùng thử", owing: "Đang nợ",
    suspended: "Tạm ngưng", new: "Chưa có kỳ"
  }.freeze
  def payment_label = PAYMENT_LABELS[payment_state]

  def access_blocked_reason
    if status == "suspended"
      return auto_suspended? ? :unpaid : :suspended
    end
    d = subscription_overdue_days
    return :unpaid if d && d > GRACE_DAYS
    nil
  end
  def access_blocked? = access_blocked_reason.present?

  def owner = memberships.find_by(role: "owner")&.user || users.first

  def contact_phone
    branding.presence&.dig("contact_phone").presence || main_branch&.phone.presence || owner&.phone.presence
  end
  def billing_email = owner&.email

  def auto_suspended? = status == "suspended" && settings["auto_suspended"] == true

  def auto_suspend_for_nonpayment!
    update!(status: "suspended", settings: settings.merge("auto_suspended" => true))
  end

  def auto_renew? = auto_renew

  def next_billing_period
    if subscription_active?
      d = paid_until.to_date + 1.day
      start = (d.day == 1) ? d : (d.beginning_of_month + 1.month)
    else
      start = Date.current.beginning_of_month
    end
    [start, start.end_of_month]
  end

  def first_billing_period
    return next_billing_period unless trial? && paid_until.present?
    start = paid_until.to_date + 1.day
    [start, start.end_of_month]
  end

  # Giá phải trả ngay bây giờ cho `plan_key` và kỳ nó bao phủ. Trang thanh toán
  # báo đúng con số này TRƯỚC khi đẩy sang PayOS, và hoá đơn dựng từ đây — số
  # khách đồng ý là số khách bị trừ.
  def checkout_quote(plan_key)
    price = Plan.for(plan_key).price
    period = if plan_key != plan && subscription_active? && !trial?
      [Date.current.beginning_of_month, Date.current.end_of_month]
    else
      first_billing_period
    end
    amount = prorated_amount(price, period)
    inv = invoices.pending.order(:period_start).first
    return [inv.amount, inv.period_start, inv.period_end] if inv && inv.plan == plan_key && inv.amount == amount

    [amount, period.first, period.last]
  end

  def prorated_amount(price, period = first_billing_period)
    price = price.to_i
    return price unless trial?
    s, e = period
    covered = (e - s).to_i + 1
    days_in_month = e.day
    return price if covered >= days_in_month
    ((price * covered) / days_in_month.to_f / 1000).round * 1000
  end

  # ---- Bộ màu / chữ (white-label từng spa) ------------------------------
  DEFAULT_THEME = {
    "primary"      => "#2F6F63",  # jade — tông wellness, trầm và sạch
    "primary_2"    => "#C9A96A",  # champagne gold
    "on_primary"   => "#FFFFFF",
    "surface"      => "#FAF7F2",  # trắng ngà ấm
    "surface_2"    => "#F1EAE0",
    "ink"          => "#2A2622",
    "ink_2"        => "#6B635A",
    "line"         => "#E4DBCF",
    "radius"       => "20px",
    "font_display" => "Fraunces",
    "font_body"    => "Plus Jakarta Sans"
  }.freeze

  FONT_STACKS = {
    "Fraunces"          => '"Fraunces", Georgia, "Times New Roman", serif',
    "Playfair Display"  => '"Playfair Display", Georgia, serif',
    "Cormorant Garamond" => '"Cormorant Garamond", Georgia, serif',
    "Plus Jakarta Sans" => '"Plus Jakarta Sans", ui-sans-serif, system-ui, sans-serif',
    "Inter"             => '"Inter", ui-sans-serif, system-ui, sans-serif',
    "Be Vietnam Pro"    => '"Be Vietnam Pro", ui-sans-serif, system-ui, sans-serif'
  }.freeze

  # Preset bộ màu sẵn cho spa chọn nhanh khi khai trương.
  THEME_PRESETS = {
    "jade"    => { "name" => "Jade & vàng champagne", "primary" => "#2F6F63", "primary_2" => "#C9A96A",
                   "surface" => "#FAF7F2", "surface_2" => "#F1EAE0", "line" => "#E4DBCF" },
    "rose"    => { "name" => "Hồng đất", "primary" => "#A8574F", "primary_2" => "#D9A5A0",
                   "surface" => "#FDF7F5", "surface_2" => "#F6E7E3", "line" => "#EFD9D4" },
    "charcoal" => { "name" => "Than & đồng", "primary" => "#2C2C2C", "primary_2" => "#B08D57",
                    "surface" => "#F7F6F4", "surface_2" => "#EBE8E4", "line" => "#DCD8D3" },
    "lotus"   => { "name" => "Sen tím", "primary" => "#6A4C93", "primary_2" => "#E0B1CB",
                   "surface" => "#FBF8FC", "surface_2" => "#F1E9F5", "line" => "#E5D9EC" },
    "ocean"   => { "name" => "Biển xanh", "primary" => "#1F6F8B", "primary_2" => "#99C8D8",
                   "surface" => "#F5FAFC", "surface_2" => "#E6F1F6", "line" => "#D5E7EE" }
  }.freeze

  def theme_value(key)
    stored = theme.presence&.dig(key.to_s).presence
    return stored if stored
    # Màu chữ trên nền thương hiệu là SUY RA, không cố định: một màu nhạt do spa
    # tự chọn mà vẫn in chữ trắng thì không ai đọc được.
    return readable_ink(theme_value(:primary)) if key.to_s == "on_primary"
    DEFAULT_THEME[key.to_s]
  end

  INK_LIGHT = "#FFFFFF".freeze
  INK_DARK  = "#1A1A1A".freeze

  def readable_ink(hex)
    l = relative_luminance(hex)
    return DEFAULT_THEME["on_primary"] if l.nil?
    contrast(l, relative_luminance(INK_DARK)) > contrast(l, relative_luminance(INK_LIGHT)) ? INK_DARK : INK_LIGHT
  end

  def relative_luminance(hex)
    m = hex.to_s.delete("#")
    return nil unless m.match?(/\A[0-9a-fA-F]{6}\z/)
    r, g, b = m.scan(/../).map do |c|
      v = c.to_i(16) / 255.0
      v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4
    end
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def contrast(l1, l2)
    hi, lo = [l1, l2].max, [l1, l2].min
    (hi + 0.05) / (lo + 0.05)
  end

  def css_radius
    r = theme_value(:radius).to_s.strip
    r.match?(/\A\d+(\.\d+)?\z/) ? "#{r}px" : (r.presence || "16px")
  end

  def resolved_theme = DEFAULT_THEME.merge(theme.presence || {})

  def font_stack(key)
    FONT_STACKS[theme_value(key)] || FONT_STACKS[DEFAULT_THEME[key]]
  end

  def apply_theme_preset!(key)
    preset = THEME_PRESETS[key.to_s]
    return false unless preset
    update!(theme: theme.merge(preset.except("name")))
  end

  # ---- Nhận diện --------------------------------------------------------
  DEFAULT_BRANDING = {
    "logo_text"     => nil,
    "tagline"       => "Spa & Massage",
    "customer_term" => "quý khách",
    "staff_term"    => "KTV",
    "city"          => nil,
    "tone"          => "calm",
    "contact_phone" => nil,
    "zalo"          => nil,
    "facebook"      => nil,
    "instagram"     => nil,
    "booking_note"  => nil
  }.freeze

  def branding_value(key)
    branding.presence&.dig(key.to_s).presence || DEFAULT_BRANDING[key.to_s]
  end

  def logo_initials
    (branding_value("logo_text") || name).to_s.split.map { |w| w[0] }.first(2).join.upcase
  end

  # ---- Ngân hàng (VietQR) -----------------------------------------------
  def bank            = settings.fetch("bank", {})
  def bank_code       = bank["code"]
  def bank_bin        = bank["bin"].presence || VietQrService.bin_for(bank_code)
  def bank_account_no = bank["account_no"]
  def bank_account_name = bank["account_name"]
  def bank_configured? = bank_bin.present? && bank_account_no.present?

  def bank_label
    VietQrService::BANKS.dig(bank_code.to_s, :name) || bank_code
  end

  private

  def within_limit?(limit, current)
    return true if limit.nil?
    current ||= ActsAsTenant.with_tenant(self) { yield }
    current < limit
  end

  def default_subdomain
    self.subdomain = slug if subdomain.blank? && slug.present?
    self.subdomain ||= name.to_s.parameterize
  end
end
