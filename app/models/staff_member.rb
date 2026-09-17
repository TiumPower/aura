# Nhân sự của spa: KTV, lễ tân, tư vấn, quản lý. Tách khỏi `User` vì phần lớn
# KTV KHÔNG có tài khoản đăng nhập — nhưng vẫn phải xếp ca, tính hoa hồng và
# hiện trên lịch. Ai cần đăng nhập thì gắn `user_id`.
class StaffMember < ApplicationRecord
  acts_as_tenant(:workspace)

  ROLES = %w[therapist receptionist consultant manager other].freeze
  ROLE_LABELS = {
    "therapist" => "Kỹ thuật viên", "receptionist" => "Lễ tân",
    "consultant" => "Tư vấn / sale", "manager" => "Quản lý", "other" => "Khác"
  }.freeze

  STATUSES = %w[active on_leave inactive].freeze
  STATUS_LABELS = { "active" => "Đang làm", "on_leave" => "Đang nghỉ phép", "inactive" => "Đã nghỉ" }.freeze

  EMPLOYMENT_TYPES = %w[fulltime parttime freelance].freeze
  EMPLOYMENT_LABELS = { "fulltime" => "Toàn thời gian", "parttime" => "Bán thời gian", "freelance" => "Khoán/tự do" }.freeze

  GENDERS = %w[female male other].freeze
  GENDER_LABELS = { "female" => "Nữ", "male" => "Nam", "other" => "Khác" }.freeze

  belongs_to :workspace
  belongs_to :branch, optional: true
  belongs_to :user, optional: true
  belongs_to :staff_level, optional: true
  has_many :staff_branches, dependent: :destroy
  has_many :branches, through: :staff_branches
  has_many :staff_shifts, dependent: :destroy
  has_many :shift_templates, dependent: :destroy
  has_one_attached :avatar

  validates :name, presence: true
  validates :role,   inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }
  validates :gender, inclusion: { in: GENDERS }, allow_blank: true
  validates :code, uniqueness: { scope: :workspace_id }, allow_blank: true

  scope :active,     -> { where(status: "active") }
  scope :therapists, -> { where(role: "therapist") }
  scope :bookable,   -> { active.therapists.where(online_bookable: true) }
  scope :ordered,    -> { order(Arel.sql("NULLIF(code, '') NULLS LAST"), :name) }
  # Lọc theo cơ sở: chi nhánh chính HOẶC một trong các chi nhánh phụ. Dùng
  # subquery thay vì join + DISTINCT — DISTINCT đụng với ORDER BY theo biểu thức
  # (`NULLIF(code,'')`) và Postgres từ chối cả câu truy vấn.
  scope :at_branch, ->(branch_id) {
    next all if branch_id.blank?
    where("staff_members.branch_id = :b OR staff_members.id IN " \
          "(SELECT staff_member_id FROM staff_branches WHERE branch_id = :b)", b: branch_id)
  }

  def active?      = status == "active"
  def therapist?   = role == "therapist"
  def role_label   = ROLE_LABELS[role] || role
  def status_label = STATUS_LABELS[status] || status
  def gender_label = GENDER_LABELS[gender]
  def level_name   = staff_level&.name

  # Tên khách và lễ tân gọi nhau: "KTV 07 · Lan".
  def display_name
    label = nickname.presence || name
    code.present? ? "#{code} · #{label}" : label
  end

  def initials = name.to_s.split.map { |w| w[0] }.first(2).join.upcase

  def color = calendar_color.presence || StaffMember.palette_color(id)

  PALETTE = %w[#2F6F63 #A8574F #6A4C93 #1F6F8B #B07C29 #4C7A34 #8B3A62 #37627E].freeze
  def self.palette_color(seed) = PALETTE[seed.to_i % PALETTE.size]

  # Phụ thu khi khách chọn KTV này (theo hạng).
  def surcharge = staff_level&.surcharge.to_i

  # % hoa hồng áp cho KTV này: của riêng → của hạng → tham số workspace.
  def commission_rate
    commission_percent.presence || staff_level&.commission_percent.presence ||
      workspace.setting_i("commission_default_percent")
  end

  # Chi nhánh KTV này có thể làm (chi nhánh chính + các chi nhánh phụ).
  def branch_ids_all
    ([branch_id] + staff_branches.pluck(:branch_id)).compact.uniq
  end

  def works_at?(branch_id) = branch_ids_all.include?(branch_id.to_i)

  # Khoảng giờ KTV có mặt trong một ngày, đã trừ nghỉ phép.
  def work_windows(date)
    rows = staff_shifts.where(work_date: date)
    working = rows.select { |s| s.kind == "shift" }.map { |s| [s.starts_at, s.ends_at] }
    blocked = rows.reject { |s| s.kind == "shift" }.map { |s| [s.starts_at, s.ends_at] }
    blocked.each { |b| working = working.flat_map { |w| Branch.subtract(w, b) } }
    working
  end

  def on_duty?(date) = work_windows(date).any?
end
