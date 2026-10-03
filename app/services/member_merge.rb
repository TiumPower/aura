# Gộp một hồ sơ khách vào hồ sơ khác.
#
# Khách đăng nhập bằng SĐT, nhưng lễ tân cũng tạo hồ sơ cho khách walk-in, nên
# một người có thể có hai hồ sơ: một bên giữ lịch sử booking, bên kia giữ thẻ
# liệu trình và ví. Đây là cách quản lý nhập chúng về một chỗ.
#
# Ba điều quyết định toàn bộ cách làm ở đây:
#
#   1. CHUYỂN dữ liệu TRƯỚC, XOÁ hồ sơ thừa SAU. Member khai
#      `dependent: :destroy` cho notifications/push/member_packages/ví/điểm và
#      `dependent: :nullify` cho bookings/orders — xoá trước là mất sạch.
#   2. `conversations` có UNIQUE [workspace_id, member_id] VÀ member_id NOT NULL,
#      nên không thể chỉ update_all: phải dồn tin nhắn rồi xoá hội thoại thừa.
#   3. `point_transactions.balance_after` và `wallet_transactions.balance_after`
#      là SỐ DƯ LUỸ TIẾN đã lưu. Trộn hai sổ vào nhau làm mọi dòng sau đó thành
#      số ảo, nên phải tính lại toàn bộ theo thứ tự thời gian.
class MemberMerge
  Result = Struct.new(:ok, :error, :moved, keyword_init: true) do
    def ok? = !!ok
  end

  def self.call(keeper:, loser:, actor: nil) = new(keeper: keeper, loser: loser, actor: actor).call

  # Gộp sẽ chuyển những gì — đếm mà không sửa gì cả. Hiện ở màn xác nhận: không
  # ai nên phải tin lời mình về một việc không hoàn lại được.
  def self.preview(keeper:, loser:)
    return {} if keeper.nil? || loser.nil?
    {
      "lịch hẹn"        => Booking.unscoped.where(member_id: loser.id).count,
      "đơn hàng"        => Order.unscoped.where(member_id: loser.id).count,
      "thẻ liệu trình"  => MemberPackage.unscoped.where(member_id: loser.id).count,
      "giao dịch điểm"  => PointTransaction.unscoped.where(member_id: loser.id).count,
      "giao dịch ví"    => WalletTransaction.unscoped.where(member_id: loser.id).count,
      "thông báo"       => Notification.unscoped.where(member_id: loser.id).count,
      "tin nhắn"        => Message.unscoped.where(sender_member_id: loser.id).count
    }.reject { |_, count| count.zero? }
  end

  def initialize(keeper:, loser:, actor: nil)
    @keeper = keeper
    @loser  = loser
    @actor  = actor
    @moved  = Hash.new(0)
  end

  def call
    return failure("Thiếu hồ sơ để gộp.")                  if @keeper.nil? || @loser.nil?
    return failure("Không thể gộp một hồ sơ với chính nó.") if @keeper.id == @loser.id
    return failure("Hai hồ sơ không cùng một spa.")         if @keeper.workspace_id != @loser.workspace_id

    ActiveRecord::Base.transaction do
      lock_both!
      move_history!
      move_conversation!
      move_unique!(PushSubscription, [:endpoint])
      repoint_audit_logs!
      absorbed = absorb_profile!
      @loser.reload.destroy!
      finish!(absorbed)
    end
    Result.new(ok: true, moved: @moved)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error("[MemberMerge] #{@loser&.id} → #{@keeper&.id} thất bại: #{e.class}: #{e.message}")
    failure(e.message)
  end

  private

  def failure(message) = Result.new(ok: false, error: message, moved: {})

  # Khoá theo thứ tự id để hai người cùng gộp các cặp chồng nhau thì xếp hàng
  # chứ không deadlock.
  def lock_both!
    [@keeper, @loser].sort_by(&:id).each(&:lock!)
  end

  PLAIN = [
    ["Booking",           :member_id],
    ["Order",             :member_id],
    ["MemberPackage",     :member_id],
    ["Notification",      :member_id],
    ["PointTransaction",  :member_id],
    ["WalletTransaction", :member_id],
    # Không index, không khoá ngoại, và tên cột không chứa đúng "member_id" ở
    # đầu — cột dễ bỏ sót nhất trong schema.
    ["Message",           :sender_member_id]
  ].freeze

  def move_history!
    PLAIN.each do |class_name, fk|
      model = class_name.safe_constantize or next
      @moved[model.table_name] += model.unscoped.where(fk => @loser.id)
                                       .update_all(fk => @keeper.id, updated_at: Time.current)
    end
    # Hồ sơ bị gộp cũng là người được giới thiệu bởi/giới thiệu người khác.
    Member.unscoped.where(referred_by_member_id: @loser.id).where.not(id: @keeper.id)
          .update_all(referred_by_member_id: @keeper.id)
    @keeper.update_columns(referred_by_member_id: nil) if @keeper.referred_by_member_id == @loser.id
  end

  # conversations: UNIQUE [workspace_id, member_id] và member_id NOT NULL. Nếu
  # khách giữ lại đã có hội thoại thì dồn tin nhắn sang rồi xoá hội thoại thừa;
  # chưa có thì chuyển thẳng.
  def move_conversation!
    theirs = Conversation.unscoped.find_by(member_id: @loser.id)
    return if theirs.nil?

    mine = Conversation.unscoped.find_by(workspace_id: @keeper.workspace_id, member_id: @keeper.id)
    if mine.nil?
      theirs.update_columns(member_id: @keeper.id)
      @moved["conversations"] += 1
      return
    end

    @moved["messages_moved"] += Message.unscoped.where(conversation_id: theirs.id)
                                      .update_all(conversation_id: mine.id, updated_at: Time.current)
    mine.update_columns(
      last_message_at: [mine.last_message_at, theirs.last_message_at].compact.max,
      staff_unread:  mine.staff_unread + theirs.staff_unread,
      member_unread: mine.member_unread + theirs.member_unread
    )
    theirs.destroy!
    @moved["conversations_merged"] += 1
  end

  # Chuyển từng dòng, vì `unique_on` + member_id là một unique index: cùng một
  # máy đăng ký push ở cả hai hồ sơ thì không thể thành hai dòng cùng endpoint.
  def move_unique!(model, unique_on, fk: :member_id)
    held = model.unscoped.where(fk => @keeper.id).pluck(*unique_on).map { |v| Array(v) }.to_set

    model.unscoped.where(fk => @loser.id).find_each do |row|
      key = unique_on.map { |column| row[column] }
      if held.include?(key)
        row.destroy!
        @moved["#{model.table_name}_merged"] += 1
      else
        row.update_columns(fk => @keeper.id)
        held << key
        @moved[model.table_name] += 1
      end
    end
  end

  # audit_logs trỏ tới Member qua target_type/target_id (polymorphic), nên grep
  # `member_id` không thấy. Không chuyển thì lịch sử thao tác trỏ vào một id đã
  # bị xoá.
  def repoint_audit_logs!
    return unless defined?(AuditLog)
    @moved["audit_logs"] += AuditLog.unscoped
                                    .where(target_type: "Member", target_id: @loser.id)
                                    .update_all(target_id: @keeper.id)
  end

  # Hồ sơ giữ lại nhận những gì nó còn thiếu. Trả về những gì hồ sơ kia mang
  # theo, để ghi vết: `phone` unique theo workspace nên số của hồ sơ bị gộp sẽ
  # mất cùng với dòng đó.
  def absorb_profile!
    snapshot = @loser.slice(:id, :name, :phone, :email, :code, :status, :source)

    @keeper.name          = @loser.name if @keeper.name.blank?
    @keeper.email       ||= @loser.email
    @keeper.gender      ||= @loser.gender
    @keeper.dob         ||= @loser.dob
    @keeper.address_line  = @loser.address_line if @keeper.address_line.blank?
    @keeper.city          = @loser.city         if @keeper.city.blank?
    @keeper.home_branch_id     ||= @loser.home_branch_id
    @keeper.preferred_staff_id ||= @loser.preferred_staff_id

    # Các con số đếm là dữ liệu denormalized của CÙNG một người, nên cộng lại.
    @keeper.visits_count   += @loser.visits_count
    @keeper.no_show_count  += @loser.no_show_count
    @keeper.cancel_count   += @loser.cancel_count
    @keeper.total_spent    += @loser.total_spent
    @keeper.first_visit_at = [@keeper.first_visit_at, @loser.first_visit_at].compact.min
    @keeper.last_visit_at  = [@keeper.last_visit_at, @loser.last_visit_at].compact.max
    @keeper.last_seen_at   = [@keeper.last_seen_at, @loser.last_seen_at].compact.max
    # Bị chặn ở một hồ sơ thì vẫn là bị chặn.
    if @loser.blocked? && !@keeper.blocked?
      @keeper.status         = "blocked"
      @keeper.blocked_at     = @loser.blocked_at
      @keeper.blocked_reason = @loser.blocked_reason
    end
    @keeper.save!(validate: false)

    snapshot
  end

  # `phone` unique theo workspace nên hồ sơ giữ lại chỉ nhận được số sau khi
  # dòng kia đã bị xoá.
  def finish!(absorbed)
    @keeper.phone = absorbed["phone"] if @keeper.phone.blank? && absorbed["phone"].present?
    @keeper.code  = absorbed["code"]  if @keeper.code.blank?  && absorbed["code"].present?
    @keeper.save!(validate: false) if @keeper.changed?

    rebuild_ledger!(PointTransaction, amount_column: :points)
    rebuild_ledger!(WalletTransaction, amount_column: :amount)
    @keeper.refresh_tier!

    trace = (@keeper.settings["merged_from"] ||= [])
    trace << absorbed.merge("at" => Time.current.iso8601, "by" => @actor&.email, "moved" => @moved)
    @keeper.update_column(:settings, @keeper.settings)

    Rails.logger.info("[MemberMerge] #{absorbed['id']} → #{@keeper.id} #{@moved.inspect}")
  end

  # `balance_after` là số dư luỹ tiến đã lưu. Sau khi trộn hai sổ, mọi dòng phải
  # được tính lại theo đúng thứ tự thời gian — nếu không, lịch sử ví/điểm mà
  # khách xem trong app là những con số không có thật.
  def rebuild_ledger!(model, amount_column:)
    running = 0
    model.unscoped.where(member_id: @keeper.id).order(:created_at, :id).each do |row|
      running += row[amount_column].to_i
      row.update_columns(balance_after: running) if row.balance_after != running
    end
    column = model == PointTransaction ? :points_balance : :wallet_balance
    @keeper.update_columns(column => running)
    @moved["#{model.table_name}_rebuilt"] = running
  end
end
