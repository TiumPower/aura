require "test_helper"

# Hai luồng đăng nhập là POST nên crawl kiểu "mở trang xem có 200" KHÔNG bao giờ
# chạm tới. Cả hai đều đã hỏng thật trên production mà 108 test vẫn xanh.
class LoginFlowsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @ws = create(:workspace, subdomain: "loginspa")
    @user = create(:user, email: "quanly@spa.test", password: "password123")
    Membership.create!(user: @user, workspace: @ws, role: "owner")
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
  end

  test "nhân sự đăng nhập bằng mật khẩu" do
    post "/merchant/login", params: { email: "quanly@spa.test", password: "password123", mode: "password" }
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "nhân sự đăng nhập bằng OTP qua email" do
    # Nút "Gửi mã đăng nhập qua email (OTP)" từng ném ArgumentError vì controller
    # còn gọi API cũ `OtpChallenge.issue!(email:, scope: "landlord")`.
    assert_difference -> { OtpChallenge.count }, 1 do
      post "/merchant/login", params: { email: "quanly@spa.test", mode: "otp" }
    end
    assert_redirected_to merchant_verify_path

    challenge = OtpChallenge.order(:created_at).last
    assert_equal "merchant", challenge.scope
    assert_equal "quanly@spa.test", challenge.identifier

    get merchant_verify_path
    assert_response :success

    post merchant_verify_submit_path, params: { code: challenge.code }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match "Tổng quan", response.body
  end

  test "mã OTP sai thì không cho vào" do
    post "/merchant/login", params: { email: "quanly@spa.test", mode: "otp" }
    post merchant_verify_submit_path, params: { code: "000000" }
    # Điều quan trọng không phải mã HTTP mà là KHÔNG được đăng nhập.
    get "/merchant"
    assert_redirected_to merchant_login_path
  end

  test "email chưa có tài khoản không tạo được OTP" do
    assert_no_difference -> { OtpChallenge.count } do
      post "/merchant/login", params: { email: "khong-ton-tai@spa.test", mode: "otp" }
    end
  end
end

# Trang chi tiết workspace ở cổng Super Admin dùng SLUG trong URL (FriendlyId
# ghi đè to_param), và nó đã 500 hoàn toàn vì view gọi `Branch#full_address` —
# method của Estate. Crawl trước đó bỏ sót vì script tự đoán id.
class AdminWorkspacePagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = AdminUser.create!(name: "Ops", email: "ops@aura.test", role: "superadmin",
                               password: "password123", password_confirmation: "password123")
    @ws = create(:workspace, subdomain: "adminspa", name: "Spa Kiểm Thử")
    ActsAsTenant.current_tenant = @ws
    @branch = create(:branch, workspace: @ws, address_line: "12 Lê Lợi",
                     ward: "Bến Nghé", district: "Quận 1", city: "TP.HCM")
    create(:room, workspace: @ws, branch: @branch)
    create(:staff_member, workspace: @ws, branch: @branch)
    create(:member, workspace: @ws)
    ActsAsTenant.current_tenant = nil
    sign_in @admin
  end

  test "trang chi tiết workspace mở được bằng SLUG và in ra địa chỉ cơ sở" do
    get "/admin/workspaces/#{@ws.slug}"
    assert_response :success
    assert_match @branch.name, response.body
    assert_match "12 Lê Lợi", response.body, "phải in địa chỉ cơ sở (short_address)"
  end

  test "mọi trang của Super Admin render" do
    ["/admin", "/admin/workspaces", "/admin/workspaces/new",
     "/admin/workspaces/#{@ws.slug}", "/admin/billing", "/admin/plans", "/admin/account"].each do |path|
      get path
      assert_response :success, "#{path} trả về #{response.status}"
    end
  end
end

# Khách tắt "nhận tin ưu đãi" trong app thì thông báo marketing KHÔNG được gửi
# tới họ. Trước đây view còn ghi thẳng "khách đã tắt vẫn nằm trong nhóm" — tức
# là app hứa một điều rồi hệ thống làm điều ngược lại.
class AnnouncementConsentTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @ws = create(:workspace, subdomain: "consentspa")
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    @user = create(:user)
    Membership.create!(user: @user, workspace: @ws, role: "owner")
    ActsAsTenant.current_tenant = @ws
    @yes = create(:member, workspace: @ws, marketing_opt_in: true)
    @no  = create(:member, workspace: @ws, marketing_opt_in: false)
    ActsAsTenant.current_tenant = nil
    sign_in @user
  end

  def send_announcement(extra = {})
    post "/merchant/announcements",
         params: { title: "Ưu đãi tháng 10", body: "Giảm 20%", segment: "all" }.merge(extra)
  end

  test "thông báo marketing không gửi cho khách đã tắt nhận tin" do
    send_announcement
    assert_response :redirect
    assert_equal 1, Notification.where(member_id: [@yes.id, @no.id]).count
    assert_equal @yes.id, Notification.last.member_id
  end

  test "thông báo vận hành thì gửi cho cả khách đã tắt nhận tin" do
    send_announcement(operational: "1")
    assert_response :redirect
    assert_equal 2, Notification.where(member_id: [@yes.id, @no.id]).count
  end

  test "trang soạn thông báo đếm đúng số người sẽ nhận" do
    get "/merchant/announcements/new"
    assert_response :success
    assert_match "1 khách", response.body, "mặc định phải trừ khách đã tắt nhận tin"
  end
end
