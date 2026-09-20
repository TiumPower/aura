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
end
