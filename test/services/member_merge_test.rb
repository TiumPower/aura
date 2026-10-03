require "test_helper"

# Gộp hồ sơ là việc không hoàn lại được, nên những ca đáng test là những ca mà
# cách làm hồn nhiên sẽ sai: unique index trên conversations/push_subscriptions,
# các con số đếm denormalized, và `balance_after` của hai sổ ví/điểm.
class MemberMergeTest < ActiveSupport::TestCase
  setup do
    @ws = create(:workspace, subdomain: "gophoso")
    ActsAsTenant.current_tenant = @ws
    @keeper = create(:member, workspace: @ws, name: "Chị Lan", phone: "0901111111",
                              email: "lan@example.com")
    @loser  = create(:member, workspace: @ws, name: "Chị Lan", phone: "0902222222", email: nil)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def merge! = MemberMerge.call(keeper: @keeper.reload, loser: @loser.reload)

  # ---- chặn trước ---------------------------------------------------------

  test "không gộp một hồ sơ với chính nó" do
    assert_not MemberMerge.call(keeper: @keeper, loser: @keeper).ok?
  end

  test "không gộp khách của hai spa khác nhau" do
    other = create(:workspace, subdomain: "spakhac")
    stranger = ActsAsTenant.with_tenant(other) { create(:member, workspace: other) }
    assert_not MemberMerge.call(keeper: @keeper, loser: stranger).ok?
    assert stranger.reload.persisted?
  end

  # ---- sổ ví và sổ điểm ---------------------------------------------------

  # `balance_after` là số dư luỹ tiến đã lưu. Trộn hai sổ mà không tính lại thì
  # lịch sử ví khách xem trong app là những con số không có thật.
  test "số dư luỹ tiến của ví được tính lại theo đúng thứ tự thời gian" do
    WalletTransaction.create!(workspace: @ws, member: @keeper, kind: "topup", amount: 500_000,
                              balance_after: 500_000, created_at: 3.days.ago)
    WalletTransaction.create!(workspace: @ws, member: @loser,  kind: "topup", amount: 200_000,
                              balance_after: 200_000, created_at: 2.days.ago)
    WalletTransaction.create!(workspace: @ws, member: @keeper, kind: "spend", amount: -100_000,
                              balance_after: 400_000, created_at: 1.day.ago)

    assert merge!.ok?

    rows = WalletTransaction.where(member_id: @keeper.id).order(:created_at).pluck(:balance_after)
    assert_equal [500_000, 700_000, 600_000], rows,
                 "mỗi dòng phải là số dư thật tại thời điểm đó sau khi trộn hai sổ"
    assert_equal 600_000, @keeper.reload.wallet_balance
  end

  test "số dư điểm cũng được tính lại" do
    PointTransaction.create!(workspace: @ws, member: @keeper, kind: "earn", points: 100,
                             balance_after: 100, created_at: 2.days.ago)
    PointTransaction.create!(workspace: @ws, member: @loser,  kind: "earn", points: 250,
                             balance_after: 250, created_at: 1.day.ago)

    assert merge!.ok?
    assert_equal [100, 350], PointTransaction.where(member_id: @keeper.id)
                                             .order(:created_at).pluck(:balance_after)
    assert_equal 350, @keeper.reload.points_balance
  end

  # ---- unique index -------------------------------------------------------

  # conversations có UNIQUE [workspace_id, member_id] VÀ member_id NOT NULL, nên
  # không thể chỉ update_all: phải dồn tin nhắn rồi xoá hội thoại thừa.
  test "hai hội thoại được dồn thành một, không mất tin nhắn" do
    mine   = Conversation.create!(workspace: @ws, member: @keeper, member_unread: 1)
    theirs = Conversation.create!(workspace: @ws, member: @loser, member_unread: 2)
    Message.create!(workspace: @ws, conversation: mine,   sender_kind: "member",
                    sender_member_id: @keeper.id, body: "Em muốn đổi giờ")
    Message.create!(workspace: @ws, conversation: theirs, sender_kind: "member",
                    sender_member_id: @loser.id, body: "Cho em hỏi giá")

    assert merge!.ok?

    assert_equal 1, Conversation.where(member_id: @keeper.id).count
    assert_not Conversation.exists?(theirs.id)
    assert_equal 2, Message.where(conversation_id: mine.id).count
    assert_equal 3, mine.reload.member_unread, "số tin chưa đọc của hai bên phải cộng lại"
  end

  test "hồ sơ giữ lại chưa có hội thoại thì nhận luôn hội thoại kia" do
    theirs = Conversation.create!(workspace: @ws, member: @loser)
    assert merge!.ok?
    assert_equal @keeper.id, theirs.reload.member_id
  end

  test "cùng một máy đăng ký push ở hai hồ sơ thì chỉ còn một" do
    PushSubscription.create!(workspace: @ws, member: @keeper, endpoint: "https://push/same",
                             p256dh: "k", auth: "a")
    PushSubscription.create!(workspace: @ws, member: @loser, endpoint: "https://push/same",
                             p256dh: "k", auth: "a")
    assert merge!.ok?
    assert_equal 1, PushSubscription.where(member_id: @keeper.id).count
  end

  # ---- các con số đếm -----------------------------------------------------

  test "số lần đến và tổng chi tiêu của hai hồ sơ được cộng lại" do
    @keeper.update_columns(visits_count: 3, total_spent: 1_500_000, no_show_count: 1,
                           first_visit_at: 10.days.ago, last_visit_at: 2.days.ago)
    @loser.update_columns(visits_count: 2, total_spent: 800_000, no_show_count: 1,
                          first_visit_at: 20.days.ago, last_visit_at: 1.day.ago)

    assert merge!.ok?
    @keeper.reload
    assert_equal 5, @keeper.visits_count
    assert_equal 2_300_000, @keeper.total_spent
    assert_equal 2, @keeper.no_show_count
    assert_in_delta 20.days.ago.to_i, @keeper.first_visit_at.to_i, 60
    assert_in_delta 1.day.ago.to_i, @keeper.last_visit_at.to_i, 60
  end

  # Bị chặn ở một hồ sơ thì gộp xong vẫn phải là bị chặn, nếu không việc gộp
  # trở thành cách lách lệnh chặn.
  test "bị chặn ở hồ sơ kia thì hồ sơ giữ lại cũng bị chặn" do
    @loser.update!(status: "blocked", blocked_at: Time.current, blocked_reason: "No-show 3 lần")
    assert merge!.ok?
    @keeper.reload
    assert @keeper.blocked?
    assert_equal "No-show 3 lần", @keeper.blocked_reason
  end

  # ---- dữ liệu khác -------------------------------------------------------

  test "lịch hẹn và thẻ liệu trình chuyển sang hồ sơ giữ lại" do
    branch = create(:branch, workspace: @ws)
    Booking.create!(workspace: @ws, branch: branch, member: @loser, starts_at: 1.day.from_now,
                    ends_at: 1.day.from_now + 1.hour, status: "confirmed")
    assert merge!.ok?
    assert_equal 1, Booking.where(member_id: @keeper.id).count
  end

  test "email ở hồ sơ kia được hồ sơ giữ lại nhận" do
    @keeper.update_columns(email: nil)
    @loser.update!(email: "lan2@example.com")
    assert merge!.ok?
    assert_equal "lan2@example.com", @keeper.reload.email
  end

  # `phone` unique theo workspace nên số của hồ sơ bị gộp mất cùng với dòng đó —
  # phải ghi lại ở đâu đó.
  test "những gì hồ sơ bị gộp mang theo được ghi lại trên hồ sơ giữ lại" do
    loser_id = @loser.id
    assert merge!.ok?
    trace = @keeper.reload.settings["merged_from"]
    assert_equal 1, trace.size
    assert_equal loser_id, trace.first["id"]
    assert_equal "0902222222", trace.first["phone"]
  end

  test "lịch sử thao tác trỏ vào hồ sơ bị gộp được trỏ lại" do
    log = AuditLog.create!(workspace: @ws, action: "customer.update",
                           target_type: "Member", target_id: @loser.id,
                           created_at: Time.current)
    assert merge!.ok?
    assert_equal @keeper.id, log.reload.target_id
  end
end
