module Customer
  class ChatController < BaseController
    before_action :require_workspace!
    before_action :require_member!
    
    def show
      @conversation = Conversation.for_member(current_member)
      @conversation.mark_read!("member")
      @messages = @conversation.messages.order(:created_at).to_a
    end

    # Polling fallback for realtime when WebSockets (/cable) are unavailable.
    # Returns turbo_stream appends for any messages newer than the client's last id.
    def updates
      @conversation = Conversation.for_member(current_member)
      after = params[:after].to_i
      msgs = @conversation.messages.where("id > ?", after).order(:created_at).to_a
      @conversation.mark_read!("member") if msgs.any?
      render turbo_stream: msgs.map { |m|
        turbo_stream.append("messages", partial: "shared/message", locals: { message: m })
      }.join.html_safe
    end

    def create_message
      @conversation = Conversation.for_member(current_member)
      body = params[:body].to_s.strip
      files = Array(params[:files]).reject(&:blank?)
      message = nil
      if body.present? || files.any?
        message = @conversation.post!(sender_kind: "member", body: body, member: current_member, files: files)
        notify_staff_chat(message)
      end
      respond_to do |format|
        format.turbo_stream do
          if message
            render turbo_stream: turbo_stream.append("messages", partial: "shared/message", locals: { message: message })
          else
            head :no_content
          end
        end
        format.html { redirect_to member_chat_path }
      end
    end

    # Sửa tin nhắn của chính khách.
    def update_message
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

    # Xoá tin nhắn của chính khách.
    def destroy_message
      message = own_message
      return head(:forbidden) unless message
      message.broadcast_remove_to(message.conversation, target: "message_#{message.id}")
      message.destroy
      head :ok
    end

    private

    def own_message
      conv = Conversation.for_member(current_member)
      msg = conv.messages.find_by(id: params[:id])
      msg if msg && msg.sender_member_id == current_member.id
    end

    # Báo cho quầy: badge realtime + push tới thiết bị của nhân sự.
    def notify_staff_chat(message)
      @conversation.broadcast_staff_badge!
      user_ids = current_workspace.users.pluck(:id)
      return if user_ids.empty?
      PushSender.deliver_to_users(user_ids,
        title: "Tin nhắn mới · #{current_member.display_name}",
        body: (message.body.presence || "📎 Tệp đính kèm").truncate(80),
        path: "/merchant/chat/#{@conversation.id}")
    rescue => e
      Rails.logger.error("[Chat] staff notify failed: #{e.class} #{e.message}")
    end
  end
end
