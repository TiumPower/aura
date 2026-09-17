class User < ApplicationRecord
  # Merchant staff / owner. Belongs to workspaces via memberships.
  # No :registerable — signup is our own custom flow (Merchant::SignupsController),
  # and Devise's shared views reference new_user_registration_path (a route we
  # skip), which 500s the password/reset pages if registerable is on.
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable, :trackable

  LOCALES = %w[vi en].freeze

  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :staff_members, dependent: :nullify

  validates :name, presence: true
  validates :locale, inclusion: { in: LOCALES }

  def membership_for(workspace)
    return nil unless workspace
    memberships.find { |m| m.workspace_id == workspace.id } ||
      memberships.find_by(workspace_id: workspace.id)
  end

  # Vai trò trong một workspace. Mọi phân quyền đọc từ đây, không từ cột nào
  # trên `users` — một người có thể là chủ ở spa này và lễ tân ở spa khác.
  def role_in(workspace) = membership_for(workspace)&.role

  def owner_of?(workspace) = membership_for(workspace)&.owner?

  # Bản ghi nhân sự tương ứng trong một workspace (nếu chủ spa đã gắn).
  def staff_in(workspace)
    staff_members.find_by(workspace_id: workspace&.id)
  end

  def display_locale
    LOCALES.include?(locale) ? locale : "vi"
  end

  def initials
    name.to_s.split.map { |w| w[0] }.first(2).join.upcase.presence || email[0, 2].upcase
  end
end
