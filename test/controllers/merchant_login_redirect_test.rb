require "test_helper"

# Đăng nhập chủ hộ ở host gốc rồi chuyển sang subdomain của chủ hộ.
#
# Lỗi từng xảy ra trên production và KHÔNG thể lộ ra trong dev: `merchant_url_for`
# chỉ trả URL tuyệt đối khi `force_subdomain_links?` (tức production), nên ở dev
# nó là path tương đối và redirect chạy bình thường. Trên production Rails chặn
# redirect chéo host → 500, đăng nhập chủ hộ chết hẳn. Test này giả lập đúng
# trạng thái đó.
class MerchantLoginRedirectTest < ActionDispatch::IntegrationTest
  setup do
    @ws = create(:workspace, subdomain: "minhanh")
    @user = create(:user, email: "chuho@aura.local", password: "aura1234")
    Membership.create!(user: @user, workspace: @ws, role: "owner")
    # Bật đúng nhánh sinh URL tuyệt đối mà production dùng (không có mocha nên
    # ghi đè thẳng phương thức, teardown bỏ đi để trả về bản kế thừa).
    Merchant::SessionsController.class_eval { def force_subdomain_links? = true }
  end

  teardown do
    Merchant::SessionsController.send(:remove_method, :force_subdomain_links?)
  end

  test "đăng nhập bằng mật khẩu chuyển sang subdomain của chủ hộ, không nổ 500" do
    post "/merchant/login", params: { email: "chuho@aura.local", password: "aura1234" }
    assert_response :redirect
    assert_equal "https://minhanh.#{ApplicationController::PLATFORM_HOST}/merchant", response.location
  end

  test "đang đăng nhập rồi mở lại trang login thì chuyển tiếp, không nổ 500" do
    post "/merchant/login", params: { email: "chuho@aura.local", password: "aura1234" }
    get "/merchant/login"
    assert_response :redirect
    assert_equal "https://minhanh.#{ApplicationController::PLATFORM_HOST}/merchant", response.location
  end
end
