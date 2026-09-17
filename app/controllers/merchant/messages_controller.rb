module Merchant
  class MessagesController < BaseController
    def create
      conversation = current_workspace.conversations.find(params[:conversation_id])
      body = params[:body].to_s.strip
      files = Array(params[:files]).reject(&:blank?)
      message = nil
      if body.present? || files.any?
        message = conversation.post!(sender_kind: "staff", body: body, user: current_user, files: files)
        notify_member(conversation, body.presence || "📎 Đã gửi tệp đính kèm")
      end
      respond_to do |format|
        format.turbo_stream do
          if message
            render turbo_stream: turbo_stream.append("messages", partial: "shared/message", locals: { message: message })
          else
            head :no_content
          end
        end
        format.html { redirect_to merchant_conversation_path(conversation) }
      end
    end

    # Sửa tin nhắn do chính mình gửi.
    def update
      message = own_message
      return head(:forbidden) unless message
      body = params[:body].to_s.strip
      if body.present?
        message.update(body: body)
        message.broadcast_replace_to(message.conversation, target: "message_#{message.id}",
                                     partial: "shared/message", locals: { message: message })
      end
      head :ok
    end

    # Xoá tin nhắn do chính mình gửi.
    def destroy
      message = own_message
      return head(:forbidden) unless message
      message.broadcast_remove_to(message.conversation, target: "message_#{message.id}")
      message.destroy
      head :ok
    end

    private

    def own_message
      conversation = current_workspace.conversations.find(params[:conversation_id])
      msg = conversation.messages.find_by(id: params[:id])
      msg if msg && msg.sender_user_id == current_user.id
    end

    def notify_member(conversation, body)
      PushJob.perform_later(current_workspace.id, [conversation.member_id],
                            "Tin nhắn từ #{current_workspace.name}", body.truncate(80), "/chat")
    rescue => e
      Rails.logger.error("[Chat] notify failed: #{e.message}")
    end
  end
end
