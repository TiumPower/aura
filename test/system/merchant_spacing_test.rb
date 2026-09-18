require "application_system_test_case"

# Quét hình học cả cổng quản lý. Lỗi `style:` bị bỏ trên `form_with` chạm 31 form
# ở ba cổng, nên sửa một trang là chưa đủ — test này mở từng trang có form và đo
# khoảng hở thật giữa các ô.
class MerchantSpacingTest < ApplicationSystemTestCase
  setup do
    @ws = create(:workspace, subdomain: "space")
    ActsAsTenant.current_tenant = @ws
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    @user = create(:user, email: "chu@space.test", password: "password123")
    Membership.create!(user: @user, workspace: @ws, role: "owner")

    @type   = create(:room_type, workspace: @ws)
    @branch = create(:branch, workspace: @ws)
    @branch.ensure_hours!
    create(:room, workspace: @ws, branch: @branch, room_type: @type)
    @level  = create(:staff_level, workspace: @ws, surcharge: 50_000)
    @staff  = create(:staff_member, workspace: @ws, branch: @branch, staff_level: @level)
    @tier   = create(:member_tier, workspace: @ws)
    @member = create(:member, workspace: @ws, member_tier: @tier)
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 450_000)
    create(:expense, workspace: @ws, branch: @branch)

    d = Date.current
    @ws.staff_shifts.create!(staff_member: @staff, branch: @branch, work_date: d, kind: "shift",
                             starts_at: Time.zone.local(d.year, d.month, d.day, 9),
                             ends_at:   Time.zone.local(d.year, d.month, d.day, 21))
    @booking = BookingScheduler.create(
      branch: @branch, starts_at: Time.zone.local(d.year, d.month, d.day, 10),
      member: @member, lines: [{ service: @service, staff: @staff }], source: "staff"
    ).booking

    @package = @ws.packages.create!(name: "Thẻ 10 buổi", kind: "session_pack", price: 3_900_000)
    @package.package_lines.create!(workspace: @ws, service: @service, sessions: 10)
    @card = @member.member_packages.create!(workspace: @ws, package: @package, name: @package.name,
                                            kind: "session_pack", purchased_on: Date.current)
    @card.package_credits.create!(workspace: @ws, service: @service, total_sessions: 10)

    visit "/merchant/login"
    fill_in "email", with: "chu@space.test"
    fill_in "password", with: "password123"
    click_on "Đăng nhập"
    assert_text "Tổng quan"
  end

  def cramped_on(path)
    visit path
    cramped_pairs
  end

  PAGES = %w[
    /merchant
    /merchant/calendar
    /merchant/bookings/queue
    /merchant/customers
    /merchant/services
    /merchant/staff
    /merchant/shifts
    /merchant/expenses
    /merchant/packages
    /merchant/bills
    /merchant/branches
    /merchant/settings
    /merchant/payment
  ].freeze

  [[390, "điện thoại"], [1400, "máy tính"]].each do |width, label|
    test "không trang merchant nào có ô dính nhau ở khổ #{label}" do
      page.driver.browser.manage.window.resize_to(width, 1600)
      problems = {}
      PAGES.each do |path|
        bad = cramped_on(path)
        problems[path] = bad if bad.any?
      end
      assert_empty problems, problems.map { |p, b| "#{p}: #{b.join(', ')}" }.join("\n")
    end
  end

  test "trang chi tiết cũng không có ô dính nhau" do
    page.driver.browser.manage.window.resize_to(390, 1600)
    paths = ["/merchant/bookings/#{@booking.id}",
             "/merchant/customers/#{@member.id}",
             "/merchant/services/#{@service.id}",
             "/merchant/staff/#{@staff.id}",
             "/merchant/member_packages/#{@card.id}",
             "/merchant/branches/#{@branch.slug}"]
    problems = {}
    paths.each do |path|
      bad = cramped_on(path)
      problems[path] = bad if bad.any?
    end
    assert_empty problems, problems.map { |p, b| "#{p}: #{b.join(', ')}" }.join("\n")
  end
end
