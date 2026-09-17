# Khách hàng của một spa. Vừa là bản ghi CRM (lễ tân tạo cho khách vãng lai chỉ
# với tên + SĐT), vừa là tài khoản đăng nhập PWA (SĐT + OTP). Khách walk-in chỉ
# là bản ghi chưa từng đăng nhập — KHÔNG phải một bảng khác, nhờ vậy khi khách
# tự tải app bằng đúng số đó thì toàn bộ lịch sử chi tiêu, thẻ liệu trình và
# điểm thưởng đã nằm sẵn ở đó.
class Member < ApplicationRecord
  acts_as_tenant(:workspace)
  devise :database_authenticatable, :rememberable

  LOCALES  = %w[vi en].freeze
  STATUSES = %w[active inactive blocked].freeze
  STATUS_LABELS = { "active" => "Đang hoạt động", "inactive" => "Ngưng theo dõi", "blocked" => "Bị chặn" }.freeze
  SOURCES = %w[walk_in self_signup online import referral].freeze
  SOURCE_LABELS = {
    "walk_in" => "Khách tới tiệm", "self_signup" => "Tự đăng ký app",
    "online" => "Đặt lịch online", "import" => "Nhập từ file", "referral" => "Bạn bè giới thiệu"
  }.freeze
  GENDERS = %w[female male other].freeze
  GENDER_LABELS = { "female" => "Nữ", "male" => "Nam", "other" => "Khác" }.freeze

  # Sở thích khách khai một lần rồi KTV nào cũng đọc được — đây là thứ khách
  # nhớ nhất về một spa "hiểu mình".
  PREFERENCE_FIELDS = {
    "pressure"      => { label: "Áp lực tay", options: ["Nhẹ", "Trung bình", "Mạnh", "Rất mạnh"] },
    "staff_gender"  => { label: "Giới tính KTV", options: ["Nữ", "Nam", "Không quan trọng"] },
    "oil"           => { label: "Tinh dầu", options: ["Sả chanh", "Oải hương", "Bạc hà", "Không mùi"] },
    "room_temp"     => { label: "Nhiệt độ phòng", options: ["Mát", "Vừa", "Ấm"] },
    "chat"          => { label: "Trò chuyện", options: ["Thích nói chuyện", "Im lặng nghỉ ngơi"] },
    "music"         => { label: "Nhạc", options: ["Nhạc thiền", "Không nhạc", "Tuỳ spa"] }
  }.freeze

  belongs_to :workspace
  belongs_to :member_tier, optional: true
  belongs_to :preferred_staff, class_name: "StaffMember", optional: true
  belongs_to :home_branch, class_name: "Branch", optional: true
  belongs_to :referred_by_member, class_name: "Member", optional: true
  has_many :referrals, class_name: "Member", foreign_key: :referred_by_member_id, dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_one  :conversation, dependent: :destroy
  has_one_attached :avatar

  validates :phone, presence: true,
                    uniqueness: { scope: :workspace_id },
                    format: { with: /\A0\d{8,10}\z/, message: "không đúng dạng số điện thoại Việt Nam" }
  validates :locale, inclusion: { in: LOCALES }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :gender, inclusion: { in: GENDERS }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  before_validation :normalize_phone
  before_validation :normalize_email
  before_validation :split_dob
  before_create :assign_referral_code

  scope :newest_first, -> { order(created_at: :desc) }
  scope :active,  -> { where(status: "active") }
  scope :blocked, -> { where(status: "blocked") }
  scope :with_app, -> { where.not(last_seen_at: nil) }
  scope :birthday_in, ->(month) { where(dob_month: month) }
  scope :search, ->(q) {
    next all if q.blank?
    t = "%#{q.to_s.strip.downcase}%"
    where("LOWER(members.name) LIKE :t OR members.phone LIKE :t OR LOWER(COALESCE(members.email,'')) LIKE :t OR LOWER(COALESCE(members.code,'')) LIKE :t", t: t)
  }

  def active?  = status == "active"
  def blocked? = status == "blocked"
  def status_label = STATUS_LABELS[status] || status
  def source_label = SOURCE_LABELS[source] || source
  def gender_label = GENDER_LABELS[gender]
  def app_user? = last_seen_at.present?

  def display_name = name.presence || phone
  def display_locale = LOCALES.include?(locale) ? locale : "vi"

  def initials
    display_name.to_s.split.map { |w| w[0] }.first(2).join.upcase.presence || phone.to_s[-2, 2]
  end

  # Số điện thoại che bớt — KTV không cần thấy đủ số của khách (tham số
  # `staff_can_see_customer_phone`).
  def masked_phone
    return phone if phone.blank? || phone.length < 7
    "#{phone[0, 4]}***#{phone[-3, 3]}"
  end

  def preference(key) = preferences[key.to_s].presence
  def preference_label(key) = PREFERENCE_FIELDS.dig(key.to_s, "label") || PREFERENCE_FIELDS.dig(key.to_s, :label)

  def tier_name = member_tier&.name
  def tier_discount = member_tier&.discount_percent.to_i

  # Chặn đặt online khi khách bỏ hẹn quá nhiều lần — ngưỡng do spa đặt.
  def booking_blocked?
    return true if blocked?
    limit = workspace.setting_i("block_after_no_shows")
    limit.positive? && no_show_count >= limit
  end

  # Nâng hạng theo chi tiêu tích luỹ. Gọi sau khi đóng bill.
  def refresh_tier!
    best = MemberTier.best_for(workspace, spent: total_spent, visits: visits_count)
    return if best.nil? || best.id == member_tier_id
    update!(member_tier: best)
  end

  # Chuẩn hoá số VN về dạng 0xxxxxxxxx: +84 / 84 / 0084 đều về một dạng, bỏ mọi
  # dấu cách và gạch. Không làm việc này thì cùng một khách tạo được ba hồ sơ.
  def self.canonical_phone(raw)
    d = raw.to_s.gsub(/\D/, "")
    return nil if d.blank?
    d = d.sub(/\A0+84/, "84")
    d = "0#{d[2..]}" if d.start_with?("84") && d.length >= 11
    d = "0#{d}" unless d.start_with?("0")
    d
  end

  def self.canonical_email(raw)
    e = raw.to_s.strip.downcase
    return nil if e.blank?
    return e unless e.include?("@")
    local, domain = e.split("@", 2)
    local = local.split("+", 2).first.to_s
    if %w[gmail.com googlemail.com].include?(domain)
      local  = local.delete(".")
      domain = "gmail.com"
    end
    local.present? ? "#{local}@#{domain}" : e
  end

  private

  def normalize_phone
    self.phone = self.class.canonical_phone(phone)
  end

  def normalize_email
    self.email = self.class.canonical_email(email)
  end

  # Lưu riêng ngày/tháng sinh: rất nhiều khách chỉ khai ngày–tháng, và marketing
  # sinh nhật chỉ cần hai trường đó.
  def split_dob
    return if dob.blank?
    self.dob_day   = dob.day
    self.dob_month = dob.month
  end

  def assign_referral_code
    return if referral_code.present?
    loop do
      code = SecureRandom.alphanumeric(6).upcase
      unless Member.unscoped.where(workspace_id: workspace_id, referral_code: code).exists?
        self.referral_code = code
        break
      end
    end
  end
end
