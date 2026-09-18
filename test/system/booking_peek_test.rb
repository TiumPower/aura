require "application_system_test_case"

# Bấm vào một khối trên lịch ngày phải mở POPUP, không rời trang. Test tích hợp
# chỉ chứng minh được máy chủ trả đúng hai dạng phản hồi; việc <dialog> có mở
# thật hay không nằm ở JavaScript, nên phải chạy trình duyệt thật mới biết.
class BookingPeekTest < ApplicationSystemTestCase
  setup do
    @ws = create(:workspace, subdomain: "peek")
    ActsAsTenant.current_tenant = @ws
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    @user = create(:user, email: "letan@peek.test", password: "password123")
    Membership.create!(user: @user, workspace: @ws, role: "owner")

    @type   = create(:room_type, workspace: @ws)
    @branch = create(:branch, workspace: @ws)
    @branch.ensure_hours!
    @room    = create(:room, workspace: @ws, branch: @branch, room_type: @type)
    @staff   = create(:staff_member, workspace: @ws, branch: @branch)
    @service = create(:service, workspace: @ws, duration_minutes: 60)
    @member  = create(:member, workspace: @ws, name: "Khách Xem Nhanh",
                      health_notes: "Thoát vị đĩa đệm nhẹ, tránh ấn mạnh thắt lưng.")

    d = Date.current
    @ws.staff_shifts.create!(staff_member: @staff, branch: @branch, work_date: d, kind: "shift",
                             starts_at: Time.zone.local(d.year, d.month, d.day, 9),
                             ends_at:   Time.zone.local(d.year, d.month, d.day, 21))
    @booking = BookingScheduler.create(
      branch: @branch, starts_at: Time.zone.local(d.year, d.month, d.day, 10),
      member: @member, lines: [{ service: @service, staff: @staff }], source: "staff"
    ).booking

    visit "/merchant/login"
    fill_in "email", with: "letan@peek.test"
    fill_in "password", with: "password123"
    click_on "Đăng nhập"
    # Chờ đăng nhập xong hẳn. `click_on` trả về trước khi điều hướng kết thúc,
    # nên `visit` ngay sau đó có thể chạy khi còn ở trang đăng nhập và trang lịch
    # bị chuyển về /merchant/login — test đỏ vì lý do không liên quan.
    assert_text "Tổng quan"
  end

  test "bấm khối trên lịch mở popup, không rời trang lịch" do
    visit "/merchant/calendar"
    assert_selector ".cal-b"
    refute_selector "dialog[open]", visible: :all

    find(".cal-b", match: :first).click

    # Dialog mở, và URL KHÔNG đổi — đó là điểm khác với bản cũ đi sang trang khác.
    assert_selector "dialog[open]"
    assert_includes page.current_path, "/merchant/calendar"
    within "dialog[open]" do
      assert_text "Khách Xem Nhanh"
      assert_text "Mở trang đầy đủ"
      # Lưu ý sức khoẻ là thứ lễ tân phải thấy trước khi cho khách vào phòng.
      assert_text "Thoát vị đĩa đệm"
      # Việc cần cân nhắc vẫn ở trang đầy đủ, không nhồi vào popup.
      assert_no_text "Đổi giờ hẹn"
    end
  end

  test "đóng popup bằng nút X thì vẫn ở lại lịch" do
    visit "/merchant/calendar"
    find(".cal-b", match: :first).click
    assert_selector "dialog[open]"

    within("dialog[open]") { click_on "✕" }
    refute_selector "dialog[open]"
    assert_includes page.current_path, "/merchant/calendar"
    assert_selector ".cal-b"
  end

  test "bấm ra ngoài thẻ cũng đóng popup" do
    visit "/merchant/calendar"
    find(".cal-b", match: :first).click
    assert_selector "dialog[open]"

    # Bấm vào chính <dialog> (vùng nền), không phải thẻ bên trong.
    page.execute_script(<<~JS)
      const d = document.querySelector("dialog[open]");
      const r = d.getBoundingClientRect();
      d.dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: r.left + 2, clientY: r.top + 2 }));
    JS
    refute_selector "dialog[open]"
  end

  test "mở trang đầy đủ từ popup thì thoát khỏi frame, không lồng trang trong popup" do
    visit "/merchant/calendar"
    find(".cal-b", match: :first).click
    within("dialog[open]") { click_on "Mở trang đầy đủ →" }

    # assert_text chờ điều hướng; assert_includes trên current_path thì KHÔNG
    # chờ, nên phải đặt sau. Nhãn "Đổi giờ hẹn" nằm trong .l-eyebrow có
    # text-transform:uppercase nên text thấy được là chữ hoa — bám câu mô tả
    # bên dưới nó thay vì bám nhãn.
    assert_text "Cả khối giờ được dịch cùng nhau"
    assert_includes page.current_path, "/merchant/bookings/#{@booking.id}"
    refute_selector "dialog[open]"
  end
  test "popup nằm giữa màn hình, không dán vào góc" do
    visit "/merchant/calendar"
    find(".cal-b", match: :first).click
    assert_selector "dialog[open]"

    # Đo bằng hình học thật: tâm hộp phải trùng tâm khung nhìn (sai số 2px cho
    # số lẻ). Reset CSS của app từng xoá `margin:auto` của <dialog> và hộp dán
    # vào góc trên trái — lỗi đó không có assert nào về nội dung bắt được.
    # Đo theo documentElement.clientWidth/Height — đó là mốc mà `position:fixed`
    # dùng. `window.innerWidth` có tính cả thanh cuộn nên lệch vài px dù hộp
    # đã căn giữa đúng.
    off = page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector("dialog[open]").getBoundingClientRect();
        const d = document.documentElement;
        return [Math.abs((r.left + r.right) / 2 - d.clientWidth / 2),
                Math.abs((r.top + r.bottom) / 2 - d.clientHeight / 2)];
      })()
    JS
    assert_operator off[0], :<=, 2, "hộp lệch ngang #{off[0]}px so với tâm"
    assert_operator off[1], :<=, 2, "hộp lệch dọc #{off[1]}px so với tâm"
  end

  test "check-in ngay trong popup: popup ở lại và khối trên lịch đổi màu" do
    visit "/merchant/calendar"
    block = find(".cal-b", match: :first)
    before = block[:style]
    block.click
    assert_selector "dialog[open]"

    within("dialog[open]") { click_on "Khách đã đến" }

    # Popup KHÔNG đóng và không rời trang — đó là điểm của yêu cầu này.
    assert_selector "dialog[open]"
    assert_includes page.current_path, "/merchant/calendar"
    within "dialog[open]" do
      assert_text "Khách đã đến", count: 1 # chỉ còn là nhãn trạng thái
      assert_text "Bắt đầu làm"            # nút tiếp theo đã hiện ra
    end
    assert_equal "checked_in", @booking.reload.status

    # Khối trên lịch phía sau đã đổi màu theo trạng thái mới.
    refute_equal before, find(".cal-b", match: :first)[:style]
  end

  test "làm liên tiếp nhiều bước trong popup mà không phải mở lại" do
    visit "/merchant/calendar"
    find(".cal-b", match: :first).click
    within("dialog[open]") { click_on "Khách đã đến" }
    within("dialog[open]") { click_on "Bắt đầu làm" }
    within("dialog[open]") { click_on "Hoàn thành" }

    assert_selector "dialog[open]"
    assert_equal "completed", @booking.reload.status
    assert_includes page.current_path, "/merchant/calendar"
  end
end
