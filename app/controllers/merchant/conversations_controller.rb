module Merchant
  class ConversationsController < BaseController
    def index
      @conversations = current_workspace.conversations.active_first.includes(:member).to_a
      ids = @conversations.map(&:id)
      last_ids = Message.where(conversation_id: ids).group(:conversation_id).maximum(:id).values
      @last_messages = Message.where(id: last_ids).index_by(&:conversation_id)
      @members = current_workspace.members.active.order(:name).limit(200).to_a
    end

    def show
      @conversation = current_workspace.conversations.includes(:member).find(params[:id])
      @conversation.mark_read!("staff")
      @messages = @conversation.messages.order(:created_at).to_a
    end

    def clear
      @conversation = current_workspace.conversations.find(params[:id])
      @conversation.messages.destroy_all
      @conversation.update(last_message_at: nil, staff_unread: 0, member_unread: 0)
      Turbo::StreamsChannel.broadcast_replace_to(@conversation, target: "messages",
        html: %(<div id="messages" class="chat-scroll" data-chatroom-target="scroll"></div>)) rescue nil
      redirect_to merchant_conversation_path(@conversation), notice: "Đã xoá toàn bộ lịch sử chat."
    end

    # Mở (hoặc bắt đầu) hộp thoại với một khách.
    def for_customer
      member = current_workspace.members.find(params[:customer_id])
      redirect_to merchant_conversation_path(Conversation.for_member(member))
    end

    private

    def nav_key = :chat
  end
end
