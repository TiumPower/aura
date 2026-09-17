require "test_helper"

# Thu ngân là nơi tiền, buổi trong thẻ, ví, điểm và hoa hồng gặp nhau. Sai một
# mắt là spa mất tiền hoặc khách mất buổi, nên test bám từng mắt.
class CheckoutTest < ActiveSupport::TestCase
  def setup
    @ws = create(:workspace)
    ActsAsTenant.current_tenant = @ws
    @branch = create(:branch, workspace: @ws)
    (0..6).each { |wd| @branch.branch_hours.create!(workspace: @ws, weekday: wd, opens_at: "09:00", closes_at: "21:00") }
    create(:room, workspace: @ws, branch: @branch, capacity: 4, turnaround_minutes: 0)
    @staff   = create(:staff_member, workspace: @ws, branch: @branch, commission_percent: 20)
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 500_000)
    @member  = create(:member, workspace: @ws)
    @user    = create(:user)
    @date = Date.current + 2
    @ws.staff_shifts.create!(staff_member: @staff, branch: @branch, work_date: @date, kind: "shift",
                             starts_at: Time.zone.local(@date.year, @date.month, @date.day, 9),
                             ends_at:   Time.zone.local(@date.year, @date.month, @date.day, 21))
    @booking = BookingScheduler.create(
      branch: @branch, starts_at: Time.zone.local(@date.year, @date.month, @date.day, 10),
      member: @member, lines: [{ service: @service, staff: @staff }], source: "staff"
    ).booking
    @booking.transition_to!("checked_in")
  end

  def teardown
    ActsAsTenant.current_tenant = nil
  end

  def open_order
    res = Checkout.open_for_booking(booking: @booking, actor: @user)
    assert res.ok?, res.error
    res.order
  end

  test "opening a bill from a booking pulls in its services and therapist" do
    order = open_order
    assert_equal 1, order.order_items.count
    item = order.order_items.first
    assert_equal @staff.id, item.staff_member_id, "phải ghi KTV thực hiện để tính hoa hồng"
    assert_equal 500_000, order.total
  end

  test "opening twice reuses the same open bill instead of double-charging" do
    first = open_order
    second = Checkout.open_for_booking(booking: @booking, actor: @user).order
    assert_equal first.id, second.id
  end

  test "a bill cannot be closed while money is still owed" do
    order = open_order
    res = Checkout.close!(order: order, actor: @user)
    assert_not res.ok?
    assert_match "Còn thiếu", res.error
    assert order.reload.open?
  end

  test "closing a paid bill awards points, commission and updates the guest totals" do
    order = open_order
    Checkout.pay(order: order, method: "cash", amount: order.total, actor: @user)
    res = Checkout.close!(order: order, actor: @user)
    assert res.ok?, res.error
    order.reload

    assert order.paid?
    assert_equal 0, order.due
    # 500.000đ, 1 điểm mỗi 1.000đ → 500 điểm
    assert_equal 500, order.points_earned
    assert_equal 500, @member.reload.points_balance
    assert_equal 500_000, @member.total_spent
    assert_equal 1, @member.visits_count, "đóng bill phải hoàn tất lịch hẹn và cộng lượt đến"
    assert_equal "completed", @booking.reload.status
    # Hoa hồng 20% của 500.000đ
    assert_equal 100_000, order.commission_entries.sum(:amount)
    assert_equal @staff.id, order.commission_entries.first.staff_member_id
  end

  test "paying from the wallet moves the money out of the wallet exactly once" do
    WalletTransaction.record!(member: @member, kind: "topup", amount: 1_000_000)
    order = open_order
    res = Checkout.pay(order: order, method: "wallet", amount: 500_000, actor: @user)
    assert res.ok?, res.error
    assert_equal 500_000, @member.reload.wallet_balance
    assert Checkout.close!(order: order, actor: @user).ok?
  end

  test "the wallet refuses to go negative" do
    WalletTransaction.record!(member: @member, kind: "topup", amount: 100_000)
    order = open_order
    res = Checkout.pay(order: order, method: "wallet", amount: 500_000, actor: @user)
    assert_not res.ok?
    assert_match "Ví chỉ còn", res.error
    assert_equal 100_000, @member.reload.wallet_balance
    assert_equal 0, order.reload.paid_total, "thu tiền thất bại thì không được ghi dòng thanh toán"
  end

  test "redeeming points converts at the configured rate and refuses when short" do
    PointTransaction.record!(member: @member, kind: "earn", points: 1_000)
    order = open_order
    # 1 điểm = 100đ → 100.000đ cần 1.000 điểm
    res = Checkout.pay(order: order, method: "points", amount: 100_000, actor: @user)
    assert res.ok?, res.error
    assert_equal 0, @member.reload.points_balance
    res2 = Checkout.pay(order: order, method: "points", amount: 100_000, actor: @user)
    assert_not res2.ok?
    assert_match "điểm", res2.error
  end

  test "a package session is only deducted when the bill closes, and only once" do
    pkg = @ws.packages.create!(name: "Thẻ 10 buổi body", kind: "session_pack", price: 4_000_000)
    pkg.package_lines.create!(workspace: @ws, service: @service, sessions: 10)
    mp = @member.member_packages.create!(workspace: @ws, package: pkg, name: pkg.name,
                                         kind: pkg.kind, purchased_on: Date.current,
                                         expires_on: 1.year.from_now.to_date)
    credit = mp.package_credits.create!(workspace: @ws, service: @service, total_sessions: 10)

    order = open_order
    item = order.order_items.first
    assert_equal credit.id, item.package_credit_id, "có thẻ còn buổi thì bill phải tự trừ buổi"
    assert_equal 0, item.total, "dòng trả bằng buổi thì tiền bằng 0"
    assert_equal 0, order.total
    assert_equal 0, credit.reload.used_sessions, "chưa đóng bill thì chưa được trừ buổi"

    assert Checkout.close!(order: order, actor: @user).ok?
    assert_equal 1, credit.reload.used_sessions
    assert_equal 9, credit.remaining
    assert_equal 1, credit.package_credit_uses.count, "mỗi lần trừ buổi phải để lại dấu"
    # KTV vẫn được hoa hồng dù bill thu 0đ — họ đã làm việc.
    assert_equal 100_000, order.reload.commission_entries.sum(:amount)
  end

  test "a line paid by a package carries no discount, so reports stay honest" do
    tier = create(:member_tier, workspace: @ws, discount_percent: 10)
    @member.update!(member_tier: tier)
    pkg = @ws.packages.create!(name: "Thẻ 5 buổi", kind: "session_pack", price: 2_000_000)
    pkg.package_lines.create!(workspace: @ws, service: @service, sessions: 5)
    mp = @member.member_packages.create!(workspace: @ws, package: pkg, name: pkg.name,
                                         kind: pkg.kind, purchased_on: Date.current)
    mp.package_credits.create!(workspace: @ws, service: @service, total_sessions: 5)

    booking = BookingScheduler.create(
      branch: @branch, starts_at: Time.zone.local(@date.year, @date.month, @date.day, 14),
      member: @member, lines: [{ service: @service, staff: @staff }], source: "staff"
    ).booking
    assert booking.booking_items.first.discount_amount.positive?,
           "lịch hẹn vẫn ghi ưu đãi hạng thẻ (khách có thể chọn trả tiền)"
    booking.transition_to!("checked_in")
    order = Checkout.open_for_booking(booking: booking, actor: @user).order

    assert order.order_items.first.from_package?
    assert_equal 0, order.order_items.first.discount_amount
    assert_equal 0, order.discount_total, "trừ buổi thì không có gì để giảm giá"
    assert_equal 0, order.total
  end

  test "voiding a closed bill gives the session, wallet money and points back" do
    pkg = @ws.packages.create!(name: "Thẻ 5 buổi", kind: "session_pack", price: 2_000_000)
    pkg.package_lines.create!(workspace: @ws, service: @service, sessions: 5)
    mp = @member.member_packages.create!(workspace: @ws, package: pkg, name: pkg.name,
                                         kind: pkg.kind, purchased_on: Date.current)
    credit = mp.package_credits.create!(workspace: @ws, service: @service, total_sessions: 5)
    order = open_order
    assert Checkout.close!(order: order, actor: @user).ok?
    assert_equal 1, credit.reload.used_sessions

    assert Checkout.void!(order: order, actor: @user, reason: "Thu sai khách").ok?
    assert_equal "void", order.reload.status
    assert_equal 0, credit.reload.used_sessions, "huỷ bill phải hoàn buổi lại cho khách"
    assert_equal 0, order.commission_entries.count, "huỷ bill thì thu hồi hoa hồng"
  end

  test "selling a package creates the real card with its sessions when the bill closes" do
    pkg = @ws.packages.create!(name: "Thẻ 8 buổi foot", kind: "session_pack", price: 2_400_000,
                               validity_days: 180, commission_percent: 6)
    pkg.package_lines.create!(workspace: @ws, service: @service, sessions: 8)
    consultant = create(:staff_member, workspace: @ws, branch: @branch, role: "consultant")

    res = Checkout.open_blank(branch: @branch, member: @member, actor: @user)
    order = res.order
    Checkout.add_package(order: order, package: pkg, consultant: consultant)
    Checkout.pay(order: order, method: "cash", amount: order.reload.total, actor: @user)
    assert Checkout.close!(order: order, actor: @user).ok?

    mp = @member.member_packages.last
    assert_equal "Thẻ 8 buổi foot", mp.name
    assert_equal 8, mp.sessions_left
    assert_equal (Date.current + 180), mp.expires_on
    assert_equal consultant.id, mp.sold_by_id
    # Hoa hồng tư vấn 6% của 2.400.000đ
    assert_equal 144_000, order.reload.commission_entries.where(role: "consultant").sum(:amount)
  end

  test "a wallet top-up adds the bonus the spa configured" do
    @ws.update_business_settings!("wallet_topup_bonus_percent" => 20)
    order = Checkout.open_blank(branch: @branch, member: @member, actor: @user).order
    Checkout.add_topup(order: order, amount: 5_000_000)
    Checkout.pay(order: order, method: "cash", amount: order.reload.total, actor: @user)
    assert Checkout.close!(order: order, actor: @user).ok?
    assert_equal 6_000_000, @member.reload.wallet_balance, "nạp 5tr + thưởng 20% = 6tr"
  end

  test "a tip goes to the therapist at the configured share" do
    @ws.update_business_settings!("tip_to_staff_percent" => 80)
    order = open_order
    Checkout.add_tip(order: order, amount: 100_000, staff: @staff)
    order.reload
    assert_equal 600_000, order.total, "tip cộng vào tổng bill"
    Checkout.pay(order: order, method: "cash", amount: order.total, actor: @user)
    assert Checkout.close!(order: order, actor: @user).ok?
    tip_entry = order.reload.commission_entries.find_by(basis: "tip")
    assert_equal 80_000, tip_entry.amount
  end

  test "a whole-bill discount is split across lines so per-service revenue stays honest" do
    order = open_order
    Checkout.add_service(order: order, service: @service, staff: @staff, use_package: false)
    order.reload
    assert_equal 1_000_000, order.total
    Checkout.apply_discount(order: order, percent: 10, note: "Khách quen")
    order.reload
    assert_equal 100_000, order.order_items.sum(:discount_amount)
    assert_equal 900_000, order.total
    assert order.order_items.all? { |i| i.discount_amount.positive? },
           "giảm giá phải chia về từng dòng, không treo ở cấp bill"
  end

  test "VAT included in listed prices is reported but not added on top" do
    @ws.update_business_settings!("vat_percent" => 8, "price_includes_vat" => true)
    order = open_order
    order.reload
    assert_equal 500_000, order.total, "giá đã gồm VAT thì không cộng thêm"
    assert order.vat_total.positive?, "nhưng vẫn tách ra được phần VAT để khai báo"
  end

  test "VAT on top of listed prices is added to the total" do
    @ws.update_business_settings!("vat_percent" => 8, "price_includes_vat" => false)
    order = open_order
    order.reload
    assert_equal 540_000, order.total
  end
end

# Mọi id đến từ form đều phải được kiểm tra thuộc đúng workspace. Đây là lớp
# chặn rò rỉ dữ liệu giữa các spa dùng chung một hệ thống.
class TenantIsolationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @a = create(:workspace, subdomain: "spa-a")
    @b = create(:workspace, subdomain: "spa-b")
    @owner_a = create(:user)
    @owner_b = create(:user)
    Membership.create!(user: @owner_a, workspace: @a, role: "owner")
    Membership.create!(user: @owner_b, workspace: @b, role: "owner")
    @branch_b = ActsAsTenant.with_tenant(@b) { create(:branch, workspace: @b) }
    @staff_a  = ActsAsTenant.with_tenant(@a) { create(:staff_member, workspace: @a, branch: nil) }
    sign_in @owner_a
  end

  test "a manager cannot attach their staff record to another spa's login account" do
    patch "/merchant/staff/#{@staff_a.id}", params: {
      staff_member: { name: @staff_a.name, role: "therapist", status: "active",
                      employment_type: "fulltime", user_id: @owner_b.id }
    }
    assert_nil @staff_a.reload.user_id, "id tài khoản của spa khác phải bị bỏ qua"
  end

  test "a manager cannot move their staff to another spa's branch" do
    patch "/merchant/staff/#{@staff_a.id}", params: {
      staff_member: { name: @staff_a.name, role: "therapist", status: "active",
                      employment_type: "fulltime", branch_id: @branch_b.id }
    }
    assert_nil @staff_a.reload.branch_id, "id cơ sở của spa khác phải bị bỏ qua"
  end

  test "a manager cannot add their staff to another spa's branch as a second site" do
    patch "/merchant/staff/#{@staff_a.id}", params: {
      staff_member: { name: @staff_a.name, role: "therapist", status: "active",
                      employment_type: "fulltime" },
      extra_branch_ids: [@branch_b.id]
    }
    assert_empty @staff_a.reload.staff_branches
  end

  test "one spa cannot open another spa's booking, bill or customer" do
    other = ActsAsTenant.with_tenant(@b) do
      create(:member, workspace: @b)
    end
    get "/merchant/customers/#{other.id}"
    assert_includes [404, 302], response.status
  end
end

# Giờ-chỗ (mẫu số của tỷ lệ lấp chỗ) phải nhân theo TỪNG cơ sở rồi cộng. Lấy
# tổng giờ × tổng chỗ là nhân chỗ của cơ sở này với giờ của cơ sở kia — mẫu số
# phồng đúng bằng số cơ sở.
class CapacityHoursTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @ws = create(:workspace, subdomain: "capspa")
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    ActsAsTenant.current_tenant = @ws
    # Cơ sở A: mở 10 giờ/ngày, 2 chỗ. Cơ sở B: mở 10 giờ/ngày, 3 chỗ.
    @a = create(:branch, workspace: @ws, name: "Cơ sở A")
    @b = create(:branch, workspace: @ws, name: "Cơ sở B")
    [@a, @b].each do |br|
      (0..6).each { |wd| br.branch_hours.create!(workspace: @ws, weekday: wd, opens_at: "09:00", closes_at: "19:00") }
    end
    create(:room, workspace: @ws, branch: @a, capacity: 2)
    create(:room, workspace: @ws, branch: @b, capacity: 3)
    ActsAsTenant.current_tenant = nil
    @user = create(:user)
    Membership.create!(user: @user, workspace: @ws, role: "owner")
    sign_in @user
  end

  test "giờ-chỗ = tổng theo từng cơ sở, không phải tổng giờ × tổng chỗ" do
    # Kỳ mặc định 30 ngày. Đúng: ((10h × 2) + (10h × 3)) × 30 = 1500 giờ-chỗ.
    # Sai (lỗi cũ): (10h + 10h) × (2 + 3) × 30 = 3000 giờ-chỗ.
    get "/merchant"
    assert_response :success
    assert_match "1500.0 giờ-chỗ", response.body
    assert_no_match(/3000\.0 giờ-chỗ/, response.body)
  end

  test "tỷ lệ dùng KTV tính trên giờ KTV CÓ MẶT, không phải giờ mở cửa" do
    ActsAsTenant.with_tenant(@ws) do
      staff = create(:staff_member, workspace: @ws, branch: @a)
      d = Date.current
      # KTV có mặt 4 giờ hôm nay.
      @ws.staff_shifts.create!(staff_member: staff, branch: @a, work_date: d, kind: "shift",
                               starts_at: Time.zone.local(d.year, d.month, d.day, 9),
                               ends_at:   Time.zone.local(d.year, d.month, d.day, 13))
    end
    get "/merchant"
    assert_response :success
    assert_match "4.0 giờ KTV", response.body,
                 "mẫu số phải là giờ KTV có mặt (4h), không phải giờ mở cửa (20h)"
  end
end

# Dãy số in trên bill phải cộng ra được: lễ tân đứng trước mặt khách không giải
# thích nổi "tạm tính 360.000 − giảm 40.000 = khách trả 360.000". Lỗi đó đã ra
# production vì `subtotal` cộng từ `order_items.total` mà `total` từng dòng ĐÃ
# trừ giảm giá rồi.
class BillArithmeticTest < ActiveSupport::TestCase
  def setup
    @ws = create(:workspace)
    ActsAsTenant.current_tenant = @ws
    @branch = create(:branch, workspace: @ws)
    @member = create(:member, workspace: @ws)
    @order = Order.create!(workspace: @ws, branch: @branch, member: @member, status: "open")
    @order.order_items.create!(workspace: @ws, kind: "service", name: "Chăm sóc da cơ bản",
                               quantity: 1, unit_price: 400_000, discount_amount: 40_000,
                               total: 360_000)
    @order.recalculate!
  end

  test "tạm tính hiển thị là giá gốc, trừ giảm giá ra đúng số khách trả" do
    o = @order.reload
    assert_equal 400_000, o.subtotal_before_discount
    assert_equal 40_000, o.discount_total
    assert_equal o.subtotal_before_discount - o.discount_total, o.total,
                 "tạm tính − giảm giá phải bằng đúng số khách trả"
  end

  test "bill không giảm giá thì tạm tính không đổi" do
    o = Order.create!(workspace: @ws, branch: @branch, member: @member, status: "open")
    o.order_items.create!(workspace: @ws, kind: "service", name: "Foot massage",
                          quantity: 1, unit_price: 250_000, discount_amount: 0, total: 250_000)
    o.recalculate!
    assert_equal 250_000, o.reload.subtotal_before_discount
  end
end
