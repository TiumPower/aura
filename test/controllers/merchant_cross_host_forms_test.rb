require "test_helper"

# Mọi form dẫn tới một redirect CHÉO HOST phải tự gửi (turbo: false).
#
# Turbo không theo được redirect chéo origin: nó preflight OPTIONS rồi im lặng
# bỏ, nên nút bấm "không làm gì cả" mà chẳng có lỗi nào hiện ra. Trong dev không
# thấy được vì `merchant_url_for` trả path tương đối ngoài production.
class MerchantCrossHostFormsTest < ActionDispatch::IntegrationTest
  setup do
    @ws    = create(:workspace, subdomain: "minhanh")
    @other = create(:workspace, subdomain: "thuha")
    @user  = create(:user)
    [@ws, @other].each do |w|
      Membership.create!(user: @user, workspace: w, role: "owner")
      # Workspace chưa qua onboarding thì /merchant đẩy sang wizard.
      w.update!(settings: w.settings.merge("onboarded" => true))
    end
    sign_in @user
  end

  test "form đổi workspace không đi qua Turbo" do
    get "/merchant"
    assert_response :success
    form = css_select("form[action='#{merchant_switch_workspace_path(@other)}']").first
    assert form, "không thấy form đổi workspace (cần ≥2 workspace)"
    assert_equal "false", form["data-turbo"],
                 "form đổi workspace thiếu data-turbo=false → Turbo sẽ bỏ qua redirect sang subdomain"
  end

  test "form đăng nhập và đăng ký chủ hộ không đi qua Turbo" do
    { "/merchant/login" => merchant_login_path, "/merchant/signup" => merchant_signup_path }.each do |page, action|
      sign_out @user
      get page
      assert_response :success
      form = css_select("form[action='#{action}']").first
      assert form, "#{page}: không thấy form"
      assert_equal "false", form["data-turbo"], "#{page}: thiếu data-turbo=false"
    end
  end
end
