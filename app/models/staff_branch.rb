# KTV chạy nhiều cơ sở. Chi nhánh chính nằm ở staff_members.branch_id; bảng này
# là các cơ sở phụ họ cũng được xếp ca.
class StaffBranch < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :staff_member
  belongs_to :branch

  validates :staff_member_id, uniqueness: { scope: :branch_id }
end
