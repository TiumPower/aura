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
    @shift  = create(:staff_shift, workspace: @ws, staff_member: @staff, branch: @branch)
    @expense = create(:expense, workspace: @ws, branch: @branch)
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
      "/merchant/expenses/#{@expense.id}/edit"
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

    ["/w/#{slug}", "/w/#{slug}/notifications", "/w/#{slug}/chat", "/w/#{slug}/toi"].each do |path|
      get path
      assert_response :success, "#{path} trả về #{response.status}"
    end
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

  test "platform landing renders on a bare host" do
    sign_out @user
    get "/"
    assert_response :success
  end
end
