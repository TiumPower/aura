require "application_system_test_case"

# Trang thu ngân là trang nhiều ô nhập nhất của cổng quản lý. Test này ĐO hình
# học thật trên trình duyệt, vì lỗi đã gặp — `style:` trên `form_with` bị Rails
# bỏ im lặng nên mọi ô dính vào nhau — không làm test nội dung nào đỏ và vẫn
# trả HTTP 200.
class PosLayoutTest < ApplicationSystemTestCase
  setup do
    @ws = create(:workspace, subdomain: "pos")
    ActsAsTenant.current_tenant = @ws
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    @user = create(:user, email: "thungan@pos.test", password: "password123")
    Membership.create!(user: @user, workspace: @ws, role: "owner")

    @type   = create(:room_type, workspace: @ws)
    @branch = create(:branch, workspace: @ws)
    @branch.ensure_hours!
    create(:room, workspace: @ws, branch: @branch, room_type: @type)
    create(:staff_member, workspace: @ws, branch: @branch)
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 450_000)
    @member  = create(:member, workspace: @ws, name: "Khách POS")
    @package = @ws.packages.create!(name: "Thẻ 10 buổi massage body", kind: "session_pack", price: 3_900_000)
    @package.package_lines.create!(workspace: @ws, service: @service, sessions: 10)

    @order = Checkout.open_blank(branch: @branch, member: @member, actor: @user).order
    @order.order_items.create!(workspace: @ws, kind: "service", name: @service.name, service: @service,
                               quantity: 1, unit_price: 450_000, discount_amount: 23_000, total: 427_000)
    @order.recalculate!

    visit "/merchant/login"
    fill_in "email", with: "thungan@pos.test"
    fill_in "password", with: "password123"
    click_on "Đăng nhập"
    assert_text "Tổng quan"
  end

  test "các ô trên trang thu ngân không dính vào nhau ở khổ điện thoại" do
    page.driver.browser.manage.window.resize_to(390, 1600)
    visit merchant_order_path(@order)
    assert_text "Thêm vào bill"
    assert_empty cramped_pairs, "có ô dính nhau ở 390px"
  end

  test "các ô không dính vào nhau ở khổ máy tính" do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit merchant_order_path(@order)
    assert_text "Thêm vào bill"
    assert_empty cramped_pairs, "có ô dính nhau ở 1400px"
  end

  test "form thêm dòng vào bill thật sự là lưới, không phải form trần" do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit merchant_order_path(@order)
    assert_text "Thêm vào bill"

    grid = page.evaluate_script(<<~JS)
      (() => {
        const f = document.querySelector("form.pos-add");
        const cs = getComputedStyle(f);
        return { display: cs.display, cols: cs.gridTemplateColumns.split(" ").length, gap: parseFloat(cs.rowGap) };
      })()
    JS
    # `style:` bị bỏ thì display ra "block", cols ra 1 và gap ra NaN/0.
    assert_equal "grid", grid["display"]
    assert_operator grid["cols"], :>=, 2, "lưới phải có nhiều cột ở khổ rộng"
    assert_operator grid["gap"], :>=, 8
  end

  test "dòng thu tiền xuống hàng ở khổ hẹp thay vì bóp ô số tiền" do
    page.driver.browser.manage.window.resize_to(390, 1600)
    visit merchant_order_path(@order)
    assert_text "Thu tiền"

    w = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector("form.pos-pay-row");
        const input = row.querySelector('input[type="number"]');
        return Math.round(input.getBoundingClientRect().width);
      })()
    JS
    assert_operator w, :>=, 200, "ô số tiền bị bóp còn #{w}px ở khổ điện thoại"
  end
end
