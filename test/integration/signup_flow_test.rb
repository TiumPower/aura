require "test_helper"

# Đường đi của một spa mới: đăng ký dùng thử → chọn loại hình → cơ sở đầu tiên
# → nạp danh mục gợi ý → vào dashboard. Cả ba bước đều phải render và lưu được,
# vì đây là màn hình đầu tiên khách trả tiền nhìn thấy.
class SignupFlowTest < ActionDispatch::IntegrationTest
  def sign_up(subdomain: "newspa", email: "new@spa.test")
    post "/merchant/signup", params: {
      workspace: { name: "Spa Mới", subdomain: subdomain, business_type: "massage" },
      email: email, owner_name: "Chủ Mới", password: "password123"
    }
  end

  test "signing up creates the workspace on trial and lands on onboarding" do
    assert_difference -> { Workspace.count }, 1 do
      sign_up
    end
    ws = Workspace.find_by(subdomain: "newspa")
    assert_equal "trial", ws.status
    assert_equal "massage", ws.business_type
    assert_redirected_to %r{/merchant/onboarding}
  end

  test "the onboarding page a new spa is sent to actually renders" do
    sign_up
    follow_redirect!
    assert_response :success
    assert_match "loại hình", response.body.downcase
  end

  test "step 1 picks the business type and turns on its module preset" do
    sign_up
    ws = Workspace.find_by(subdomain: "newspa")
    patch "/merchant/onboarding", params: { step: "business", business_type: "beauty" }
    assert_response :redirect
    ws.reload
    assert_equal "beauty", ws.business_type
    # Preset của thẩm mỹ viện có bật "treatment_records", nhưng module đó chưa có
    # màn hình nào nên `enabled_modules` lọc ra — thà không bật còn hơn bật rồi
    # không có gì xảy ra. Xem BusinessSettings::COMING_SOON_MODULES.
    assert_includes Workspace::BUSINESS_TYPES, ws.business_type
    assert_includes ws.enabled_modules, "packages", "TMV phải có thẻ liệu trình"
    assert_not_includes ws.enabled_modules, "walk_in", "TMV không nhận khách vãng lai"
    assert_not_includes ws.enabled_modules, "treatment_records", "module chưa làm thì không được bật"
  end

  test "step 2 creates the first branch with a full week of opening hours" do
    sign_up
    ws = Workspace.find_by(subdomain: "newspa")
    assert_difference -> { ActsAsTenant.with_tenant(ws) { Branch.count } }, 1 do
      patch "/merchant/onboarding", params: {
        step: "branch",
        branch: { name: "Cơ sở Quận 1", city: "TP.HCM", address_line: "1 Lê Lợi" }
      }
    end
    assert_response :redirect
    branch = ActsAsTenant.with_tenant(ws) { Branch.first }
    assert_equal 7, branch.branch_hours.count, "mỗi thứ phải có một khung giờ mặc định"
    assert branch.open_on?(Date.current)
  end

  test "step 3 seeds the suggested catalogue and finishes onboarding" do
    sign_up
    ws = Workspace.find_by(subdomain: "newspa")
    patch "/merchant/onboarding", params: { step: "branch", branch: { name: "Cơ sở 1" } }
    patch "/merchant/onboarding", params: { step: "presets", seed: "1" }
    assert_response :redirect
    ws.reload
    assert ws.onboarded?
    ActsAsTenant.with_tenant(ws) do
      assert RoomType.count.positive?,   "phải có loại phòng gợi ý"
      assert StaffLevel.count.positive?, "phải có hạng KTV gợi ý"
      assert MemberTier.count.positive?, "phải có hạng thẻ gợi ý"
    end
  end

  test "an owner can skip onboarding and still get a default branch" do
    sign_up
    ws = Workspace.find_by(subdomain: "newspa")
    post "/merchant/onboarding/skip"
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert ws.reload.onboarded?
    assert ActsAsTenant.with_tenant(ws) { Branch.count }.positive?,
           "bỏ qua thiết lập vẫn phải có một cơ sở để treo phòng và lịch"
  end

  test "a taken subdomain is rejected, not exploded" do
    create(:workspace, subdomain: "taken")
    assert_no_difference -> { Workspace.count } do
      sign_up(subdomain: "taken")
    end
    assert_response :unprocessable_entity
  end
end
