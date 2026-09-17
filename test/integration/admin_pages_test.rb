require "test_helper"

# The platform operator's own console.
class AdminPagesTest < ActionDispatch::IntegrationTest
  setup do
    @ws = create(:workspace, subdomain: "adminsmoke")
    @admin = AdminUser.create!(email: "ops@aura.test", password: "password123", name: "Ops")
    sign_in @admin, scope: :admin_user
  end

  PAGES = %w[/admin /admin/workspaces /admin/workspaces/new /admin/billing /admin/plans /admin/account].freeze

  PAGES.each do |path|
    test "admin page #{path} renders" do
      get path
      assert_includes [200, 302], response.status, "#{path} returned #{response.status}"
    end
  end

  test "a workspace detail page renders" do
    get "/admin/workspaces/#{@ws.to_param}"
    assert_response :success
  end

  test "suspending and reactivating a workspace works" do
    patch "/admin/workspaces/#{@ws.to_param}/suspend"
    assert_equal "suspended", @ws.reload.status
    patch "/admin/workspaces/#{@ws.to_param}/reactivate"
    assert_equal "active", @ws.reload.status
  end
end
