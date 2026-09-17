# Số buổi còn lại của một dịch vụ trong một thẻ.
class PackageCredit < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :member_package
  belongs_to :service
  belongs_to :service_variant, optional: true
  has_many :package_credit_uses, dependent: :destroy

  validates :total_sessions, :used_sessions, numericality: { greater_than_or_equal_to: 0 }

  def remaining = [total_sessions.to_i - used_sessions.to_i, 0].max
  def label = "#{service.name}: #{remaining}/#{total_sessions} buổi"

  # Trừ một buổi và GHI LẠI dấu. Không bao giờ trừ trực tiếp bằng update_all —
  # mất dấu là mất luôn khả năng giải thích cho khách.
  def consume!(sessions: 1, booking_item: nil, order_item: nil, staff: nil, actor: nil, reason: nil)
    raise ArgumentError, "Thẻ không còn buổi" if sessions.positive? && remaining < sessions
    transaction do
      increment!(:used_sessions, sessions)
      package_credit_uses.create!(
        workspace: workspace, booking_item_id: booking_item&.id, order_item_id: order_item&.id,
        staff_member_id: staff&.id, sessions: sessions, reason: reason,
        actor_id: actor&.id, used_at: Time.current
      )
      member_package.refresh_status!
    end
    true
  end

  # Hoàn buổi (huỷ bill, làm sai, khách khiếu nại).
  def restore!(sessions: 1, actor: nil, reason: nil)
    transaction do
      decrement!(:used_sessions, [sessions, used_sessions].min)
      package_credit_uses.create!(
        workspace: workspace, sessions: -sessions, reason: reason,
        actor_id: actor&.id, used_at: Time.current
      )
      member_package.update!(status: "active") if member_package.status == "used_up" && !member_package.expired?
    end
    true
  end
end
