# Kỹ năng: KTV nào làm được dịch vụ nào.
class StaffService < ApplicationRecord
  acts_as_tenant(:workspace)

  LEVELS = { 1 => "Mới học", 2 => "Thành thạo", 3 => "Chuyên sâu" }.freeze

  belongs_to :workspace
  belongs_to :staff_member
  belongs_to :service

  validates :staff_member_id, uniqueness: { scope: :service_id }
  validates :proficiency, inclusion: { in: LEVELS.keys }

  def level_label = LEVELS[proficiency]
end
