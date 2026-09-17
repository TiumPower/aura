# Một hộp thoại giữa spa và một khách hàng.
class Conversation < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :member
  has_many :messages, dependent: :destroy

  scope :active_first, -> { order(Arel.sql("last_message_at DESC NULLS LAST"), created_at: :desc) }

  def self.for_member(member)
    find_or_create_by!(member_id: member.id) { |c| c.workspace = member.workspace }
  end

  def title = member.display_name

  # Ghi một tin nhắn và cộng số chưa đọc cho PHÍA BÊN KIA.
  def post!(sender_kind:, body:, user: nil, member: nil, files: nil)
    msg = messages.build(
      workspace: workspace, sender_kind: sender_kind, body: body.to_s,
      sender_user_id: user&.id, sender_member_id: member&.id,
      sender_name: (user&.name || member&.display_name)
    )
    attachables = Array(files).reject(&:blank?)
    msg.files.attach(attachables) if attachables.any?
    msg.save!
    bump = sender_kind == "staff" ? { member_unread: member_unread + 1 }
                                  : { staff_unread: staff_unread + 1 }
    update!(bump.merge(last_message_at: msg.created_at))
    broadcast_member_badge! if sender_kind == "staff"
    msg
  end

  def mark_read!(side)
    update!(side == "staff" ? { staff_unread: 0 } : { member_unread: 0 })
    broadcast_member_badge! if side == "member"
    broadcast_staff_badge!  if side == "staff"
  end

  def broadcast_staff_badge!
    total = workspace.conversations.where("staff_unread > 0").sum(:staff_unread)
    Turbo::StreamsChannel.broadcast_replace_to(
      workspace, "staff_chat_badge", target: "staff_chat_badge",
      partial: "layouts/staff_chat_badge", locals: { count: total })
  rescue => e
    Rails.logger.error("[Conversation] staff badge failed: #{e.class} #{e.message}")
  end

  def broadcast_member_badge!
    Turbo::StreamsChannel.broadcast_replace_to(
      self, "member_badge", target: "chat_tab_badge",
      partial: "layouts/chat_tab_badge", locals: { count: member_unread }
    )
  rescue => e
    Rails.logger.error("[Conversation] badge broadcast failed: #{e.class} #{e.message}")
  end
end
