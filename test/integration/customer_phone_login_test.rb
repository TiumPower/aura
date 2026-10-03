require "test_helper"

# Khách đăng nhập bằng SĐT + OTP. Luồng này đã có từ trước nhưng chưa có test
# nào; giờ nó gửi mã qua Zalo thật nên càng cần chốt lại hành vi.
class CustomerPhoneLoginTest < ActionDispatch::IntegrationTest
  setup do
    @ws = create(:workspace, subdomain: "khachspa")
    ActsAsTenant.current_tenant = nil
  end

  def base = "/w/#{@ws.slug}"

  def login_with_phone(phone)
    post "#{base}/vao", params: { phone: phone }
    code = otp_code_for(phone, workspace: @ws, scope: "customer")
    assert code.present?, "chưa phát mã OTP cho #{phone}"
    post "#{base}/xac-thuc", params: { code: code }
  end

  def member_for(phone) = ActsAsTenant.with_tenant(@ws) { Member.find_by(phone: phone) }

  test "khách mới đăng nhập bằng SĐT thì được tạo hồ sơ" do
    assert_difference -> { ActsAsTenant.with_tenant(@ws) { Member.count } }, 1 do
      login_with_phone("0901234567")
    end
    member = member_for("0901234567")
    assert_equal "self_signup", member.source
  end

  # Lễ tân đã tạo hồ sơ cho khách walk-in — khách tự đăng nhập phải vào ĐÚNG hồ
  # sơ đó, kèm lịch sử và thẻ liệu trình, không phải một hồ sơ trắng.
  test "khách đã có hồ sơ do lễ tân tạo thì đăng nhập vào đúng hồ sơ đó" do
    existing = ActsAsTenant.with_tenant(@ws) { create(:member, workspace: @ws, phone: "0907654321") }
    assert_no_difference -> { ActsAsTenant.with_tenant(@ws) { Member.count } } do
      login_with_phone("0907654321")
    end
    assert_equal existing.id, member_for("0907654321").id
  end

  test "gõ số theo cách khác vẫn vào đúng một hồ sơ" do
    login_with_phone("0901234567")
    delete "#{base}/logout"
    assert_no_difference -> { ActsAsTenant.with_tenant(@ws) { Member.count } } do
      login_with_phone("+84 901 234 567")
    end
  end

  test "nhập sai mã thì không ai được đăng nhập" do
    post "#{base}/vao", params: { phone: "0901234567" }
    post "#{base}/xac-thuc", params: { code: "000000" }
    assert_response :unprocessable_entity
    assert_nil member_for("0901234567")
  end

  test "số không hợp lệ thì không phát mã nào" do
    assert_no_difference -> { OtpChallenge.unscoped.count } do
      post "#{base}/vao", params: { phone: "12" }
    end
    assert_response :unprocessable_entity
  end

  test "mã của khách ghi nhận kênh Zalo" do
    post "#{base}/vao", params: { phone: "0901234567" }
    challenge = otp_challenge_for("0901234567", workspace: @ws, scope: "customer")
    assert_equal "zalo", challenge.channel
    assert_equal "customer", challenge.scope
  end
end
