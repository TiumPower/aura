require "test_helper"

# Công tắc OTP cấp nền tảng: bật là ai biết email/SĐT cũng đăng nhập hộ được,
# nên mặc định phải tắt và phải thấy rõ khi đang bật.
class AdminSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminUser.create!(email: "ops-settings@aura.test", password: "password123", name: "Ops")
    sign_in @admin, scope: :admin_user
  end

  test "hai công tắc mặc định tắt" do
    assert_not AppSetting.show_otp_customer?
    assert_not AppSetting.show_otp_staff?
    get "/admin/settings"
    assert_response :success
  end

  test "bật rồi tắt từng công tắc một, không ảnh hưởng nhau" do
    patch "/admin/settings", params: { scope: "customer", on: "true" }
    assert AppSetting.show_otp_customer?
    assert_not AppSetting.show_otp_staff?

    patch "/admin/settings", params: { scope: "staff", on: "true" }
    assert AppSetting.show_otp_staff?

    patch "/admin/settings", params: { scope: "customer", on: "false" }
    assert_not AppSetting.show_otp_customer?
    assert AppSetting.show_otp_staff?
  end

  test "mọi trang admin cảnh báo khi còn bật" do
    AppSetting.set_flag(AppSetting::SHOW_OTP_CUSTOMER_KEY, true)
    get "/admin"
    assert_response :success
    assert_match(/hiện mã OTP/i, response.body)
  end

  # ---- Panel cổng gửi OTP qua Zalo ----------------------------------------

  test "trang thiết lập báo cổng gửi chưa được cấu hình" do
    get "/admin/settings"
    assert_response :success
    assert_match(/Cổng gửi OTP qua Zalo/, response.body)
    assert_match(/Chưa cấu hình/, response.body)
  end

  # Refresh token đổi sau mỗi lần làm mới nên giá trị trong .env sẽ cũ; dán
  # token mới không được bắt deploy lại. Lưu token mới cũng phải xoá access
  # token đang cache, nếu không lần gửi sau vẫn dùng cặp token cũ.
  test "dán refresh token thì lưu lại và buộc làm mới" do
    AppSetting.set("zns_access_token", "stale")
    patch "/admin/settings/otp-gateway", params: { zns_refresh_token: "  fresh-token " }
    assert_redirected_to "/admin/settings"
    assert_equal "fresh-token", AppSetting.get("zns_refresh_token")
    assert_equal "", AppSetting.get("zns_access_token")
  end

  test "refresh token để trống thì không ghi đè cái đang có" do
    AppSetting.set("zns_refresh_token", "keep-me")
    patch "/admin/settings/otp-gateway", params: { zns_refresh_token: "" }
    assert_equal "keep-me", AppSetting.get("zns_refresh_token")
  end

  test "gửi thử tới số sai định dạng thì không gọi nhà cung cấp nào" do
    post "/admin/settings/otp-test", params: { phone: "12" }
    assert_redirected_to "/admin/settings"
    assert_match(/bad_phone/, flash[:alert])
  end

  test "chưa cấu hình cổng thì gửi thử nói thẳng, không giả vờ đã gửi" do
    post "/admin/settings/otp-test", params: { phone: "0901234567" }
    assert_redirected_to "/admin/settings"
    assert_match(/not_configured/, flash[:alert])
  end
end
