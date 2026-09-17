# Giờ mở cửa theo thứ. Nhiều dòng cùng một thứ = ca sáng và ca tối tách nhau
# (nhiều tiệm nghỉ trưa), nên đừng gộp thành một cặp mở/đóng duy nhất.
class BranchHour < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :branch

  validates :weekday, inclusion: { in: 0..6 }
  validate  :closes_after_opens

  scope :ordered, -> { order(:weekday, :opens_at) }

  def weekday_label = Branch.weekday_label(weekday)

  def range_label
    return "Nghỉ" if closed? || opens_at.blank? || closes_at.blank?
    "#{opens_at.strftime('%H:%M')} – #{closes_at.strftime('%H:%M')}"
  end

  private

  def closes_after_opens
    return if closed? || opens_at.blank? || closes_at.blank?
    errors.add(:closes_at, "phải sau giờ mở cửa") if closes_at <= opens_at
  end
end
