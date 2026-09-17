class AdminUser < ApplicationRecord
  # Platform operator (Super Admin). Not tenant-scoped — sees across workspaces.
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable

  ROLES = %w[operator superadmin].freeze
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  def superadmin? = role == "superadmin"

  def initials
    name.to_s.split.map { |w| w[0] }.first(2).join.upcase.presence || email[0, 2].upcase
  end
end
