class Notification < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :member
  belongs_to :broadcast, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read? = read_at.present?

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def display_icon
    icon.presence || { "payment" => "💳", "reminder" => "⏰", "system" => "🔔", "message" => "💬" }[kind] || "🔔"
  end
end
