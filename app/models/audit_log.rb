# Nhật ký thao tác. Sửa giá, huỷ bill, tặng buổi, đổi hoa hồng — spa nào cũng
# có tranh chấp nội bộ về mấy thao tác này, nên ghi lại là yêu cầu bắt buộc.
class AuditLog < ApplicationRecord
  acts_as_tenant(:workspace)

  self.record_timestamps = false

  belongs_to :workspace

  scope :recent, -> { order(created_at: :desc) }
  scope :for_target, ->(obj) { where(target_type: obj.class.name, target_id: obj.id) }

  def self.record!(workspace:, actor: nil, action:, target: nil, summary: nil, payload: {}, ip: nil)
    create!(
      workspace: workspace,
      actor_type: actor&.class&.name,
      actor_id: actor&.id,
      actor_name: actor.try(:display_name) || actor.try(:name) || actor.try(:email),
      action: action.to_s,
      target_type: target&.class&.name,
      target_id: target&.id,
      summary: summary,
      payload: payload || {},
      ip: ip,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.error("[AuditLog] #{e.class}: #{e.message}")
    nil
  end
end
