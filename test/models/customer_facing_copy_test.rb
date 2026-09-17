require "test_helper"

# Hai lỗi dưới đây đều lọt qua 123 test và chỉ lộ ra khi MỞ THẬT trang của khách
# trên production. Chúng cùng một dạng: view hỏi sai câu hỏi chứ không phải mã
# nổ, nên mọi kiểm tra chỉ dựa vào HTTP 200 đều mù với chúng.
class BookingCancelWindowTest < ActiveSupport::TestCase
  def setup
    @ws = create(:workspace)
    ActsAsTenant.current_tenant = @ws
    @branch = create(:branch, workspace: @ws)
    (0..6).each { |wd| @branch.branch_hours.create!(workspace: @ws, weekday: wd, opens_at: "09:00", closes_at: "21:00") }
    @member = create(:member, workspace: @ws)
  end

  def booking_at(starts_at, status)
    b = Booking.new(workspace: @ws, branch: @branch, member: @member,
                    starts_at: starts_at, ends_at: starts_at + 1.hour,
                    status: status, source: "app", party_size: 1,
                    code: SecureRandom.alphanumeric(6).upcase)
    b.save!(validate: false)
    b
  end

  test "buổi đã xong từ tháng trước không còn nói chuyện huỷ" do
    b = booking_at(30.days.ago, "completed")
    # `live?` vẫn đúng vì buổi đã xong VẪN chiếm phòng — SlotFinder cần thế.
    assert b.live?, "completed phải nằm trong LIVE_STATUSES để SlotFinder đếm chỗ"
    refute b.member_can_cancel?
    refute b.cancel_window_closed?, "buổi đã xong mà báo 'đã sát giờ hẹn' là vô nghĩa"
  end

  test "buổi bị huỷ cũng không nói chuyện huỷ" do
    refute booking_at(2.days.from_now, "cancelled").cancel_window_closed?
  end

  test "buổi sắp tới nhưng quá hạn tự huỷ thì mới hiện lời nhắc gọi spa" do
    cutoff = @branch.setting_i("cancel_cutoff_hours")
    b = booking_at((cutoff - 1).hours.from_now, "confirmed")
    refute b.member_can_cancel?
    assert b.cancel_window_closed?
  end

  test "buổi còn xa thì khách tự huỷ được, không hiện lời nhắc" do
    b = booking_at((@branch.setting_i("cancel_cutoff_hours") + 24).hours.from_now, "confirmed")
    assert b.member_can_cancel?
    refute b.cancel_window_closed?
  end
end

class ServiceVariantLabelTest < ActiveSupport::TestCase
  def setup
    @ws = create(:workspace)
    ActsAsTenant.current_tenant = @ws
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 400_000)
  end

  test "tên biến thể đã là thời lượng thì không nối thêm lần nữa" do
    v = @service.service_variants.create!(workspace: @ws, name: "90′", duration_minutes: 90, price: 620_000)
    assert_equal "90′", v.duration_label, "không được ra '90′ · 90′'"
  end

  test "tên biến thể có nghĩa riêng thì mới kèm thời lượng" do
    v = @service.service_variants.create!(workspace: @ws, name: "Gói đôi", duration_minutes: 120, price: 1_200_000)
    assert_equal "Gói đôi · 120′", v.duration_label
  end
end
