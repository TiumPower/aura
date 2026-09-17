# Một cơ sở vật lý của spa. Phòng, KTV, ca làm và lịch hẹn đều treo vào chi
# nhánh — số liệu tách được theo cơ sở mà vẫn dùng chung một danh mục dịch vụ.
class Branch < ApplicationRecord
  acts_as_tenant(:workspace)
  extend FriendlyId
  friendly_id :name, use: [:slugged, :scoped], scope: :workspace

  STATUSES = %w[active paused archived].freeze
  STATUS_LABELS = { "active" => "Đang hoạt động", "paused" => "Tạm ngưng nhận khách", "archived" => "Đã đóng" }.freeze

  belongs_to :workspace
  has_many :branch_hours, dependent: :destroy
  has_many :branch_closures, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :staff_shifts, dependent: :nullify
  has_many :staff_branches, dependent: :destroy
  has_many :staff_members, dependent: :nullify
  has_many :expenses, dependent: :nullify
  has_many :bookings, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :service_prices, dependent: :destroy
  has_one_attached :cover
  has_many_attached :photos

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active,  -> { where(status: "active") }
  scope :ordered, -> { order(:position, :name) }
  scope :bookable, -> { active.where(online_bookable: true) }

  def active?   = status == "active"
  def status_label = STATUS_LABELS[status] || status
  def display_name = name
  def short_address = [address_line, ward, district, city].compact_blank.join(", ")
  def mapped? = lat.present? && lng.present?

  # Tham số nghiệp vụ: chi nhánh ghi đè, không có thì lấy của workspace.
  def setting(key)
    own = settings.is_a?(Hash) ? settings[key.to_s] : nil
    own.nil? ? workspace.setting(key) : own
  end
  def setting_i(key) = setting(key).to_i
  def setting?(key)  = ActiveModel::Type::Boolean.new.cast(setting(key)).present?

  def update_branch_settings!(attrs)
    own = settings.dup
    attrs.each do |k, v|
      k = k.to_s
      next unless BusinessSettings::DEFAULTS.key?(k)
      (v.nil? || v == "") ? own.delete(k) : own[k] = workspace.cast_setting(k, v)
    end
    update!(settings: own)
  end

  # ---- Giờ mở cửa -------------------------------------------------------
  # Trả về các khoảng [mở, đóng] (Time) của một ngày, đã trừ phần đóng cửa đột
  # xuất. Rỗng = hôm đó không nhận khách.
  def open_windows(date)
    rows = branch_hours.where(weekday: date.wday).order(:opens_at)
    rows = rows.reject(&:closed)
    windows = rows.filter_map do |h|
      next if h.opens_at.blank? || h.closes_at.blank?
      [combine(date, h.opens_at), combine(date, h.closes_at)]
    end
    windows = [[combine(date, default_open), combine(date, default_close)]] if windows.empty? && branch_hours.empty?
    subtract_closures(windows, date)
  end

  def open_on?(date) = open_windows(date).any?

  DEFAULT_OPEN  = "09:00".freeze
  DEFAULT_CLOSE = "22:00".freeze

  def default_open  = Time.zone.parse(DEFAULT_OPEN)
  def default_close = Time.zone.parse(DEFAULT_CLOSE)

  # Tạo giờ mở cửa mặc định cho 7 ngày khi chi nhánh vừa được lập.
  def ensure_hours!
    return if branch_hours.exists?
    (0..6).each do |wd|
      branch_hours.create!(workspace: workspace, weekday: wd,
                           opens_at: default_open, closes_at: default_close)
    end
  end

  WEEKDAY_LABELS = ["Chủ nhật", "Thứ hai", "Thứ ba", "Thứ tư", "Thứ năm", "Thứ sáu", "Thứ bảy"].freeze
  # Nhãn ngắn cho lưới ngày trên điện thoại. Đừng cắt chuỗi dài bằng `sub` —
  # "Thứ hai" sẽ thành "Thai".
  WEEKDAY_SHORT = %w[CN T2 T3 T4 T5 T6 T7].freeze

  def self.weekday_label(wd) = WEEKDAY_LABELS[wd.to_i]
  def self.weekday_short(wd) = WEEKDAY_SHORT[wd.to_i]

  private

  def combine(date, time)
    Time.zone.local(date.year, date.month, date.day, time.hour, time.min)
  end

  # Cắt các khoảng đóng cửa (lễ, bảo trì) khỏi giờ mở cửa thường ngày.
  def subtract_closures(windows, date)
    closures = branch_closures.where("starts_on <= :d AND ends_on >= :d", d: date)
    return windows if closures.empty?

    closures.each do |c|
      block = if c.starts_at.present? && c.ends_at.present?
        [combine(date, c.starts_at), combine(date, c.ends_at)]
      else
        return [] # đóng cả ngày
      end
      windows = windows.flat_map { |w| Branch.subtract(w, block) }
    end
    windows
  end

  # [a,b] trừ [c,d] → 0, 1 hoặc 2 khoảng.
  def self.subtract(window, block)
    a, b = window
    c, d = block
    return [window] if d <= a || c >= b
    parts = []
    parts << [a, c] if c > a
    parts << [d, b] if d < b
    parts
  end
end
