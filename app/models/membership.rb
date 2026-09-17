# Vai trò của một tài khoản nhân sự trong một workspace.
class Membership < ApplicationRecord
  ROLES = %w[owner manager receptionist therapist accountant].freeze
  ROLE_LABELS = {
    "owner" => "Chủ spa", "manager" => "Quản lý", "receptionist" => "Lễ tân",
    "therapist" => "Kỹ thuật viên", "accountant" => "Kế toán"
  }.freeze

  belongs_to :user
  belongs_to :workspace
  belongs_to :branch, optional: true

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }

  def owner?        = role == "owner"
  def manager?      = role == "manager"
  def receptionist? = role == "receptionist"
  def therapist?    = role == "therapist"
  def accountant?   = role == "accountant"

  def admin?      = owner? || manager?
  def can_manage? = admin?
  # Ai đứng quầy: mở bill, thu tiền, xếp khách.
  def front_desk? = admin? || receptionist?
  # Ai xem được tiền: doanh thu, hoa hồng, chi phí.
  def sees_money? = admin? || accountant?

  def label = ROLE_LABELS[role] || role
end
