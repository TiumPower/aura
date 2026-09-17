# Ca làm THẬT của một KTV trong một ngày. `kind`:
#   shift    — đang có mặt, engine xếp khách vào đây
#   off      — nghỉ theo lịch
#   leave    — xin nghỉ (phép/bệnh) đã duyệt
#   training — đi học, không nhận khách
# Chỉ `shift` mở ra khả năng nhận khách; ba loại còn lại cắt bớt khoảng đó.
class StaffShift < ApplicationRecord
  acts_as_tenant(:workspace)

  KINDS = %w[shift off leave training].freeze
  KIND_LABELS = { "shift" => "Ca làm", "off" => "Nghỉ", "leave" => "Nghỉ phép", "training" => "Đào tạo" }.freeze

  belongs_to :workspace
  belongs_to :staff_member
  belongs_to :branch, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :work_date, :starts_at, :ends_at, presence: true
  validates :kind, inclusion: { in: KINDS }
  validate  :ends_after_starts

  scope :working, -> { where(kind: "shift") }
  scope :on_date, ->(date) { where(work_date: date) }
  scope :between, ->(from, to) { where(work_date: from..to) }
  scope :ordered, -> { order(:work_date, :starts_at) }

  def kind_label = KIND_LABELS[kind] || kind
  def working?   = kind == "shift"
  def hours = ((ends_at - starts_at) / 3600.0).round(2)
  def range_label = "#{starts_at.strftime('%H:%M')} – #{ends_at.strftime('%H:%M')}"

  # Sinh ca cho một khoảng ngày từ mẫu tuần. Ca đã có (dù sửa tay) KHÔNG bị ghi
  # đè — người xếp lịch sửa tay xong chạy lại sinh ca không bị mất công.
  def self.generate_from_templates!(workspace, from:, to:, staff_scope: nil)
    created = 0
    ActsAsTenant.with_tenant(workspace) do
      staff = staff_scope || workspace.staff_members.active
      templates = ShiftTemplate.where(staff_member_id: staff.map(&:id)).to_a
      (from..to).each do |date|
        templates.select { |t| t.weekday == date.wday }.each do |t|
          exists = where(staff_member_id: t.staff_member_id, work_date: date).exists?
          next if exists
          create!(workspace: workspace, staff_member_id: t.staff_member_id,
                  branch_id: t.branch_id || t.staff_member.branch_id, work_date: date,
                  starts_at: Time.zone.local(date.year, date.month, date.day, t.starts_at.hour, t.starts_at.min),
                  ends_at:   Time.zone.local(date.year, date.month, date.day, t.ends_at.hour, t.ends_at.min),
                  kind: "shift")
          created += 1
        end
      end
    end
    created
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    errors.add(:ends_at, "phải sau giờ bắt đầu") if ends_at <= starts_at
  end
end
