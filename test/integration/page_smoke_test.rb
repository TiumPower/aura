require "test_helper"

# Mọi trang GET mà chủ spa / khách / super admin có thể mở phải render được,
# không được 500. Đây là lưới an toàn rẻ nhất khi domain còn đang lớn nhanh.
class PageSmokeTest < ActionDispatch::IntegrationTest
  setup do
    @ws = create(:workspace, subdomain: "smoke", business_type: "mixed")
    ActsAsTenant.current_tenant = @ws
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    @type   = create(:room_type, workspace: @ws)
    @branch = create(:branch, workspace: @ws)
    @branch.ensure_hours!
    @room   = create(:room, workspace: @ws, branch: @branch, room_type: @type)
    @level  = create(:staff_level, workspace: @ws)
    @staff  = create(:staff_member, workspace: @ws, branch: @branch, staff_level: @level)
    @tier   = create(:member_tier, workspace: @ws)
    @member = create(:member, workspace: @ws, member_tier: @tier)
    # KTV phải có ca làm mới nhận được khách — sinh ca cho cả tuần để mọi test
    # đặt lịch (hôm nay và các ngày tới) đều có chỗ.
    (0..7).each do |offset|
      d = Date.current + offset
      @ws.staff_shifts.create!(staff_member: @staff, branch: @branch, work_date: d, kind: "shift",
                               starts_at: Time.zone.local(d.year, d.month, d.day, 9),
                               ends_at:   Time.zone.local(d.year, d.month, d.day, 21))
    end
    @shift = @ws.staff_shifts.first
    @expense = create(:expense, workspace: @ws, branch: @branch)
    @category = create(:service_category, workspace: @ws)
    @service  = create(:service, workspace: @ws, service_category: @category)
    @booking = BookingScheduler.create(branch: @branch, starts_at: Time.current.tomorrow.change(hour: 10),
                                       lines: [{ service: @service }], member: @member,
                                       source: "staff").booking
    ActsAsTenant.current_tenant = nil

    @user = create(:user)
    Membership.create!(user: @user, workspace: @ws, role: "owner")
    sign_in @user
  end

  MERCHANT_PAGES = %w[
    /merchant /merchant/account /merchant/onboarding
    /merchant/branches /merchant/branches/new
    /merchant/rooms /merchant/room-types
    /merchant/staff /merchant/staff/new /merchant/levels
    /merchant/shifts
    /merchant/customers /merchant/customers/new /merchant/tiers
    /merchant/expenses /merchant/expenses/new
    /merchant/chat /merchant/announcements/new
    /merchant/services /merchant/services/new /merchant/categories
    /merchant/calendar /merchant/bookings/new /merchant/bookings/new?walk_in=1 /merchant/bookings/queue
    /merchant/settings /merchant/settings/modules
    /merchant/appearance /merchant/payment /merchant/audit /merchant/billing
  ].freeze

  MERCHANT_PAGES.each do |path|
    test "GET #{path} renders" do
      get path
      assert_includes [200, 302], response.status, "#{path} trả về #{response.status}"
    end
  end

  test "record pages render" do
    [
      "/merchant/branches/#{@branch.slug}",
      "/merchant/branches/#{@branch.slug}/edit",
      "/merchant/branches/#{@branch.slug}/rooms/new",
      "/merchant/rooms/#{@room.id}/edit",
      "/merchant/room-types/#{@type.id}/edit",
      "/merchant/staff/#{@staff.id}",
      "/merchant/staff/#{@staff.id}/edit",
      "/merchant/levels/#{@level.id}/edit",
      "/merchant/customers/#{@member.id}",
      "/merchant/customers/#{@member.id}/edit",
      "/merchant/tiers/#{@tier.id}/edit",
      "/merchant/expenses/#{@expense.id}/edit",
      "/merchant/services/#{@service.slug}",
      "/merchant/services/#{@service.slug}/edit",
      "/merchant/categories/#{@category.id}/edit",
      "/merchant/bookings/#{@booking.id}",
      "/merchant/bookings/#{@booking.id}/edit"
    ].each do |path|
      get path
      assert_includes [200, 302], response.status, "#{path} trả về #{response.status}"
    end
  end

  test "customer app pages render for a visitor" do
    sign_out @user
    [
      "/w/#{@ws.slug}",
      "/w/#{@ws.slug}/vao"
    ].each do |path|
      get path
      assert_includes [200, 302], response.status, "#{path} trả về #{response.status}"
    end
  end

  # Khách đăng nhập bằng SĐT + OTP. Test đi hết luồng thật thay vì chỉ GET trang
  # login, vì chính luồng này quyết định khách walk-in có vào đúng hồ sơ cũ không.
  test "a guest signs in with phone + OTP and reaches every app page" do
    sign_out @user
    slug = @ws.slug
    post "/w/#{slug}/vao", params: { phone: @member.phone }
    assert_redirected_to %r{/xac-thuc}
    code = OtpChallenge.where(identifier: @member.phone, scope: "customer").order(:created_at).last.code
    post "/w/#{slug}/xac-thuc", params: { code: code }
    assert_response :redirect

    ["/w/#{slug}", "/w/#{slug}/notifications", "/w/#{slug}/chat", "/w/#{slug}/toi",
     "/w/#{slug}/dat-lich", "/w/#{slug}/lich-hen", "/w/#{slug}/lich-hen/#{@booking.id}"].each do |path|
      get path
      assert_response :success, "#{path} trả về #{response.status}"
    end
  end

  # Luồng đặt lịch của khách đi qua ba bước, mỗi bước là một query param — test
  # đi hết để không có bước nào 500 trên điện thoại khách.
  test "the guest booking flow walks service -> time -> confirm and creates a booking" do
    sign_out @user
    slug = @ws.slug
    sign_in_member!

    get "/w/#{slug}/dat-lich"
    assert_response :success
    assert_match @service.name, response.body

    get "/w/#{slug}/dat-lich", params: { branch_id: @branch.id, service_id: @service.id }
    assert_response :success

    date = (Date.current + 2).to_s
    get "/w/#{slug}/dat-lich", params: { branch_id: @branch.id, service_id: @service.id, date: date }
    assert_response :success
    slot = SlotFinder.new(branch: @branch, service: @service).slots_on(Date.parse(date)).first
    assert slot, "phải có ít nhất một giờ trống"

    get "/w/#{slug}/dat-lich", params: { branch_id: @branch.id, service_id: @service.id,
                                         date: date, time: slot.label }
    assert_response :success
    assert_match "Xác nhận lịch hẹn", response.body

    assert_difference -> { ActsAsTenant.with_tenant(@ws) { Booking.count } }, 1 do
      post "/w/#{slug}/dat-lich", params: { branch_id: @branch.id, service_id: @service.id,
                                            date: date, time: slot.label, note: "nhẹ tay" }
    end
    assert_response :redirect
    booking = ActsAsTenant.with_tenant(@ws) { Booking.order(:created_at).last }
    assert_equal "app", booking.source
    assert_equal @member.id, booking.member_id
  end

  test "a guest cannot book a slot that was just taken" do
    sign_out @user
    slug = @ws.slug
    sign_in_member!
    date = (Date.current + 2)
    slot = SlotFinder.new(branch: @branch, service: @service).slots_on(date).first
    # Quầy đặt trước đúng slot đó.
    BookingScheduler.create(branch: @branch, starts_at: slot.starts_at, guest_name: "Khách quầy",
                            lines: [{ service: @service }], source: "staff")
    assert_no_difference -> { ActsAsTenant.with_tenant(@ws) { Booking.count } } do
      post "/w/#{slug}/dat-lich", params: { branch_id: @branch.id, service_id: @service.id,
                                            date: date.to_s, time: slot.label }
    end
    assert_response :redirect
    assert_match "chọn giờ khác", flash[:alert].to_s,
                 "khách phải được nói rõ vì sao không đặt được, không chỉ im lặng quay lại"
  end

  test "a guest can cancel far enough ahead but not at the last minute" do
    sign_out @user
    slug = @ws.slug
    sign_in_member!
    far = @booking
    patch "/w/#{slug}/lich-hen/#{far.id}/huy", params: { reason: "đổi ý" }
    assert_response :redirect
    assert_equal "cancelled", far.reload.status
    assert_equal 1, @member.reload.cancel_count, "khách tự huỷ thì phải cộng vào số lần huỷ"

    soon = BookingScheduler.create(branch: @branch, starts_at: 1.hour.from_now,
                                   lines: [{ service: @service }], member: @member,
                                   source: "app").booking
    patch "/w/#{slug}/lich-hen/#{soon.id}/huy"
    assert_equal "confirmed", soon.reload.status, "sát giờ thì khách không tự huỷ được"
  end

  test "signing in with a known phone reuses the walk-in record" do
    sign_out @user
    slug = @ws.slug
    assert_no_difference -> { ActsAsTenant.with_tenant(@ws) { Member.count } } do
      post "/w/#{slug}/vao", params: { phone: @member.phone }
      code = OtpChallenge.where(identifier: @member.phone, scope: "customer").order(:created_at).last.code
      post "/w/#{slug}/xac-thuc", params: { code: code }
    end
    assert @member.reload.last_seen_at.present?, "đăng nhập phải đánh dấu khách đã dùng app"
  end

  test "a phone in +84 form lands on the same record, not a duplicate" do
    sign_out @user
    slug = @ws.slug
    intl = @member.phone.sub(/\A0/, "+84")
    assert_no_difference -> { ActsAsTenant.with_tenant(@ws) { Member.count } } do
      post "/w/#{slug}/vao", params: { phone: intl }
      code = OtpChallenge.where(identifier: @member.phone, scope: "customer").order(:created_at).last.code
      post "/w/#{slug}/xac-thuc", params: { code: code }
    end
  end

  # Đăng nhập khách bằng OTP thật, dùng lại ở nhiều test.
  def sign_in_member!
    post "/w/#{@ws.slug}/vao", params: { phone: @member.phone }
    code = OtpChallenge.where(identifier: @member.phone, scope: "customer").order(:created_at).last.code
    post "/w/#{@ws.slug}/xac-thuc", params: { code: code }
  end

  test "platform landing renders on a bare host" do
    sign_out @user
    get "/"
    assert_response :success
  end
end
