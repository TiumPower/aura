# Mẫu ca lặp theo tuần của một KTV. Dùng để SINH ra ca thật (staff_shifts) cho
# từng ngày — lịch thật mới là nguồn duy nhất để tính KTV có rảnh hay không,
# vì ca thật còn bị nghỉ phép và đổi ca ghi đè.
class ShiftTemplate < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :staff_member
  belongs_to :branch, optional: true

  validates :weekday, inclusion: { in: 0..6 }
  validates :starts_at, :ends_at, presence: true
  validate  :ends_after_starts

  scope :ordered, -> { order(:weekday, :starts_at) }

  def weekday_label = Branch.weekday_label(weekday)
  def range_label = "#{starts_at.strftime('%H:%M')} – #{ends_at.strftime('%H:%M')}"

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    errors.add(:ends_at, "phải sau giờ bắt đầu") if ends_at <= starts_at
  end
end
