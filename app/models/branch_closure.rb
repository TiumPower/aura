# Khoảng đóng cửa ngoài lịch thường: nghỉ lễ, nghỉ Tết, bảo trì, mất nước.
# Không có giờ cụ thể = đóng cả ngày.
class BranchClosure < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :branch

  validates :starts_on, :ends_on, presence: true
  validate  :ends_after_starts

  scope :upcoming, -> { where("ends_on >= ?", Date.current).order(:starts_on) }

  def all_day? = starts_at.blank? || ends_at.blank?

  def label
    span = starts_on == ends_on ? starts_on.strftime("%d/%m/%Y") :
      "#{starts_on.strftime('%d/%m')} – #{ends_on.strftime('%d/%m/%Y')}"
    all_day? ? span : "#{span} (#{starts_at.strftime('%H:%M')}–#{ends_at.strftime('%H:%M')})"
  end

  private

  def ends_after_starts
    return if starts_on.blank? || ends_on.blank?
    errors.add(:ends_on, "phải từ ngày bắt đầu trở đi") if ends_on < starts_on
  end
end
