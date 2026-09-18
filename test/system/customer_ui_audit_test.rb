require "application_system_test_case"

# Soát UI cổng KHÁCH (PWA). Khách mở app này trên điện thoại, nên khổ 390px là
# khổ chính chứ không phải khổ phụ.
class CustomerUiAuditTest < ApplicationSystemTestCase
  setup do
    @ws = create(:workspace, subdomain: "cus", name: "Aura Spa Demo")
    ActsAsTenant.current_tenant = @ws
    @ws.update!(settings: @ws.settings.merge("onboarded" => true))

    @type   = create(:room_type, workspace: @ws)
    @branch = create(:branch, workspace: @ws, name: "Aura Spa Phú Nhuận")
    @branch.ensure_hours!
    create(:room, workspace: @ws, branch: @branch, room_type: @type)
    @level  = create(:staff_level, workspace: @ws, surcharge: 100_000)
    @staff  = create(:staff_member, workspace: @ws, branch: @branch, staff_level: @level)
    @tier   = create(:member_tier, workspace: @ws)
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 450_000)
    @service.service_variants.create!(workspace: @ws, name: "90′", duration_minutes: 90, price: 620_000)
    @member = create(:member, workspace: @ws, member_tier: @tier,
                     health_notes: "Thoát vị đĩa đệm nhẹ L4-L5, tránh ấn mạnh vùng thắt lưng.")

    d = Date.current
    (0..3).each do |o|
      dd = d + o
      @ws.staff_shifts.create!(staff_member: @staff, branch: @branch, work_date: dd, kind: "shift",
                               starts_at: Time.zone.local(dd.year, dd.month, dd.day, 9),
                               ends_at:   Time.zone.local(dd.year, dd.month, dd.day, 21))
    end
    @booking = BookingScheduler.create(
      branch: @branch, starts_at: Time.zone.local(d.year, d.month, d.day, 10),
      member: @member, lines: [{ service: @service, staff: @staff }], source: "app"
    ).booking

    @package = @ws.packages.create!(name: "Thẻ 10 buổi massage body", kind: "session_pack", price: 3_900_000)
    @package.package_lines.create!(workspace: @ws, service: @service, sessions: 10)
    @card = @member.member_packages.create!(workspace: @ws, package: @package, name: @package.name,
                                            kind: "session_pack", purchased_on: Date.current)
    @card.package_credits.create!(workspace: @ws, service: @service, total_sessions: 10)

    @slug = @ws.slug
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit "/w/#{@slug}/vao"
    fill_in "phone", with: @member.phone
    click_on "Nhận mã xác thực"
    # PHẢI chờ điều hướng xong mới đọc OTP trong DB: `click_on` trả về trước khi
    # POST hoàn tất, nên truy vấn ngay sau đó là đọc lúc request còn đang bay và
    # bảng OtpChallenge vẫn rỗng.
    assert_text "Nhập mã xác thực"
    code = OtpChallenge.where(identifier: @member.phone, scope: "customer").order(:created_at).last.code
    fill_in "code", with: code
    click_on "Xác nhận"
    assert_text "Xin chào"
  end

  def pages
    ["/w/#{@slug}",
     "/w/#{@slug}/dat-lich",
     "/w/#{@slug}/dat-lich?branch_id=#{@branch.id}&service_id=#{@service.id}",
     "/w/#{@slug}/lich-hen",
     "/w/#{@slug}/lich-hen/#{@booking.id}",
     "/w/#{@slug}/the-cua-toi",
     "/w/#{@slug}/chi-tieu",
     "/w/#{@slug}/chat",
     "/w/#{@slug}/toi"]
  end

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

  # Khách mở app này trên điện thoại, nên 390px là khổ CHÍNH.
  [390, 768, 1400].each do |w|
    test "cổng khách không có lỗi hình học ở khổ #{w}px" do
      assert_clean pages, w
    end
  end
end
