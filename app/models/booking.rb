# Một lần khách tới spa. Các lượt dịch vụ cụ thể nằm ở `booking_items` — một
# lịch hẹn có thể gồm 2 khách đi cùng (2 item cùng giờ) và/hoặc nhiều dịch vụ
# nối tiếp (body 60′ rồi foot 30′).
#
# LƯU Ý cho người sửa code: KHÔNG tạo module `Booking::` (namespace) — nó sẽ va
# với model này dưới Zeitwerk. Các service liên quan để ở tên cấp cao:
# SlotFinder, BookingScheduler.
class Booking < ApplicationRecord
  acts_as_tenant(:workspace)

  STATUSES = %w[pending confirmed checked_in in_progress completed cancelled no_show].freeze
  STATUS_LABELS = {
    "pending"     => "Chờ xác nhận",
    "confirmed"   => "Đã xác nhận",
    "checked_in"  => "Khách đã đến",
    "in_progress" => "Đang làm",
    "completed"   => "Đã xong",
    "cancelled"   => "Đã huỷ",
    "no_show"     => "Khách không đến"
  }.freeze
  STATUS_COLORS = {
    "pending" => "#B08D57", "confirmed" => "#2F6F63", "checked_in" => "#1F6F8B",
    "in_progress" => "#6A4C93", "completed" => "#3F7A57",
    "cancelled" => "#8A8078", "no_show" => "#B4402F"
  }.freeze
  # Trạng thái còn chiếm chỗ trên lịch. Huỷ và no-show KHÔNG chiếm chỗ nữa —
  # nếu tính cả thì phòng trống mãi không bán lại được.
  LIVE_STATUSES = %w[pending confirmed checked_in in_progress completed].freeze

  SOURCES = %w[staff app web phone walk_in zalo].freeze
  SOURCE_LABELS = {
    "staff" => "Quầy lễ tân", "app" => "App khách", "web" => "Web",
    "phone" => "Gọi điện", "walk_in" => "Khách vãng lai", "zalo" => "Zalo"
  }.freeze

  belongs_to :workspace
  belongs_to :branch
  belongs_to :member, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :booking_items, -> { order(:starts_at, :position) }, dependent: :destroy
  has_one  :order, dependent: :nullify
  accepts_nested_attributes_for :booking_items, allow_destroy: true

  validates :code, presence: true, uniqueness: { scope: :workspace_id }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :starts_at, :ends_at, presence: true
  validate  :member_or_guest

  before_validation :assign_code, on: :create

  scope :live,      -> { where(status: LIVE_STATUSES) }
  scope :upcoming,  -> { live.where("bookings.starts_at >= ?", Time.current).order(:starts_at) }
  scope :on_date,   ->(date) { where(starts_at: date.all_day) }
  scope :between,   ->(from, to) { where(starts_at: from..to) }
  scope :recent,    -> { order(starts_at: :desc) }
  scope :at_branch, ->(id) { id.present? ? where(branch_id: id) : all }

  # ---- Trạng thái --------------------------------------------------------
  STATUSES.each do |s|
    define_method("#{s}?") { status == s }
  end

  def status_label = STATUS_LABELS[status] || status
  def status_color = STATUS_COLORS[status] || "#6B635A"
  def source_label = SOURCE_LABELS[source] || source
  def live? = LIVE_STATUSES.include?(status)
  def finished? = %w[completed cancelled no_show].include?(status)

  # Chuyển trạng thái nào là hợp lệ. Nhảy bậc (chờ xác nhận → đã xong) bị chặn
  # để không có bill nào đóng mà không ai từng bấm "khách đã đến".
  TRANSITIONS = {
    "pending"     => %w[confirmed cancelled no_show checked_in],
    "confirmed"   => %w[checked_in cancelled no_show],
    "checked_in"  => %w[in_progress completed cancelled],
    "in_progress" => %w[completed cancelled],
    "completed"   => [],
    "cancelled"   => %w[confirmed],
    "no_show"     => %w[confirmed]
  }.freeze

  def can_transition_to?(target) = TRANSITIONS.fetch(status, []).include?(target.to_s)

  def transition_to!(target, actor: nil, reason: nil)
    target = target.to_s
    return false unless can_transition_to?(target)
    attrs = { status: target }
    case target
    when "confirmed"   then attrs[:confirmed_at] = Time.current
    when "checked_in"  then attrs[:checked_in_at] = Time.current
    when "in_progress" then attrs[:started_at] = Time.current
    when "completed"   then attrs[:completed_at] = Time.current
    when "cancelled"
      attrs[:cancelled_at] = Time.current
      attrs[:cancel_reason] = reason
      attrs[:cancelled_by] = actor.is_a?(Member) ? "member" : (actor ? "staff" : "system")
    when "no_show"     then attrs[:no_show_at] = Time.current
    end
    transaction do
      update!(attrs)
      sync_item_statuses!(target)
      apply_member_counters!(target)
    end
    true
  end

  # ---- Khách -------------------------------------------------------------
  def customer_name = member&.display_name.presence || guest_name.presence || "Khách lẻ"
  def customer_phone = member&.phone.presence || guest_phone

  # ---- Giờ & nội dung ----------------------------------------------------
  def duration_minutes = ((ends_at - starts_at) / 60).round
  def time_label = "#{starts_at.strftime('%H:%M')}–#{ends_at.strftime('%H:%M')}"
  def date_label = I18n.l(starts_at.to_date, format: "%a %d/%m")

  def service_summary
    booking_items.map { |i| i.service_label }.uniq.join(" + ")
  end

  def staff_summary
    names = booking_items.filter_map { |i| i.staff_member&.display_name }.uniq
    names.presence&.join(", ") || "Chưa gán KTV"
  end

  def rooms_summary
    booking_items.filter_map { |i| i.room&.display_name }.uniq.join(", ")
  end

  def unassigned_staff? = booking_items.any? { |i| i.service.requires_staff? && i.staff_member_id.nil? }

  # Tổng tiền dự kiến, tính lại từ các lượt (giá đã chốt lúc đặt).
  def recalculate_total!
    total = booking_items.reject { |i| i.status == "cancelled" }
                         .sum { |i| i.price.to_i + i.staff_surcharge.to_i - i.discount_amount.to_i }
    span_from = booking_items.reject { |i| i.status == "cancelled" }.map(&:starts_at).min
    span_to   = booking_items.reject { |i| i.status == "cancelled" }.map(&:ends_at).max
    update!(estimated_total: total,
            starts_at: span_from || starts_at,
            ends_at: span_to || ends_at)
  end

  # Khách còn được tự huỷ / đổi giờ không (theo tham số của cơ sở).
  # `live?` gồm cả "completed" vì buổi đã xong VẪN chiếm phòng (SlotFinder phải
  # đếm nó), nên đừng dùng nó để hỏi "còn huỷ/đổi được không". Buổi đã xong từ
  # tháng trước mà màn hình khách báo "đã sát giờ hẹn nên không tự huỷ được" là
  # vô nghĩa — đó là lỗi đã gặp thật ở /lich-hen/:id.
  def cancel_window_closed?
    %w[pending confirmed].include?(status) && starts_at.future? && !member_can_cancel?
  end

  def member_can_cancel?
    return false unless %w[pending confirmed].include?(status)
    cutoff = branch.setting_i("cancel_cutoff_hours").hours
    starts_at - Time.current > cutoff
  end

  def member_can_reschedule?
    return false unless %w[pending confirmed].include?(status)
    starts_at - Time.current > branch.setting_i("reschedule_cutoff_hours").hours
  end

  # Quá giờ hẹn bao lâu mà chưa check-in.
  def late_minutes
    return 0 unless %w[pending confirmed].include?(status)
    mins = ((Time.current - starts_at) / 60).floor
    mins.positive? ? mins : 0
  end

  def late? = late_minutes > branch.setting_i("late_grace_minutes")

  private

  # Mã hẹn khách đọc qua điện thoại được: 6 ký tự, bỏ các chữ dễ đọc lẫn
  # (0/O, 1/I) để lễ tân không tra sai mã.
  ALPHABET = "23456789ACDEFGHJKLMNPQRSTUVWXYZ".chars.freeze

  def assign_code
    return if code.present?
    loop do
      candidate = Array.new(6) { ALPHABET.sample }.join
      unless Booking.unscoped.where(workspace_id: workspace_id, code: candidate).exists?
        self.code = candidate
        break
      end
    end
  end

  def member_or_guest
    return if member_id.present? || guest_name.present? || guest_phone.present?
    errors.add(:base, "Cần chọn khách hoặc nhập tên/SĐT khách lẻ")
  end

  def sync_item_statuses!(target)
    case target
    when "in_progress" then booking_items.where(status: "planned").update_all(status: "in_progress")
    when "completed"   then booking_items.where.not(status: "cancelled").update_all(status: "done")
    when "cancelled"   then booking_items.update_all(status: "cancelled")
    end
  end

  # Đếm lượt đến / bỏ hẹn của khách. Đây là số liệu cơ chế chặn đặt online đọc,
  # nên phải cộng đúng một lần, ở đúng một chỗ.
  def apply_member_counters!(target)
    return if member.nil?
    case target
    when "completed"
      member.update!(visits_count: member.visits_count + 1,
                     last_visit_at: Time.current,
                     first_visit_at: member.first_visit_at || Time.current)
    when "no_show"  then member.update!(no_show_count: member.no_show_count + 1)
    when "cancelled"
      member.update!(cancel_count: member.cancel_count + 1) if cancelled_by == "member"
    end
  end
end
