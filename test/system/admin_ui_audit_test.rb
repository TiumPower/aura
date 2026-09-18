require "application_system_test_case"

# Soát UI cổng SUPER ADMIN. Cổng này dùng trên máy tính, nhưng vẫn phải mở được
# trên điện thoại vì người vận hành nền tảng hay xử lý việc lúc đang di chuyển.
class AdminUiAuditTest < ApplicationSystemTestCase
  setup do
    @admin = AdminUser.create!(name: "Vận hành nền tảng", email: "ops@aura.test",
                               password: "password123", password_confirmation: "password123")
    @ws = create(:workspace, subdomain: "adm", name: "Aura Spa Sài Gòn")
    ActsAsTenant.current_tenant = @ws
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))
    @branch = create(:branch, workspace: @ws)
    @branch.ensure_hours!
    @user = create(:user, email: "chu@adm.test")
    Membership.create!(user: @user, workspace: @ws, role: "owner")
    ActsAsTenant.current_tenant = nil

    visit "/admin/login"
    fill_in "admin_user[email]", with: "ops@aura.test"
    fill_in "admin_user[password]", with: "password123"
    click_on "Đăng nhập"
  end

  PAGES = ["/admin", "/admin/workspaces", "/admin/workspaces/new",
           "/admin/billing", "/admin/plans", "/admin/account"].freeze

  # Soát một trang: trả về mô tả các vấn đề hình học, rỗng là sạch.
  def audit(path)
    visit path
    found = []
    if (ov = horizontal_overflow)
      found << "tràn ngang #{ov['over']}px (#{ov['culprits'].join(' | ')})"
    end
    cramped_pairs.each  { |c| found << "dính nhau: #{c}" }
    tiny_targets.each   { |t| found << "ô bấm nhỏ: #{t}" }
    clipped_text.each   { |t| found << "chữ bị cắt: #{t}" }
    found
  end

  def assert_clean(paths, width)
    page.driver.browser.manage.window.resize_to(width, 1600)
    problems = paths.to_h { |p| [p, audit(p)] }.reject { |_, v| v.empty? }
    assert_empty problems,
      "UI có vấn đề ở khổ #{width}px:\n" +
      problems.map { |p, v| "#{p}\n    - #{v.join("\n    - ")}" }.join("\n")
  end

  [390, 1400].each do |w|
    test "cổng super admin không có lỗi hình học ở khổ #{w}px" do
      assert_clean(PAGES + ["/admin/workspaces/#{@ws.slug}"], w)
    end
  end
end
