require "test_helper"

# Engine xếp lịch là nơi duy nhất trả lời "còn nhận khách được không". Mọi luật
# ở đây nếu sai thì spa phải gọi điện xin lỗi khách, nên test bám sát từng luật.
class SlotFinderTest < ActiveSupport::TestCase
  def setup
    @ws = create(:workspace, business_type: "massage")
    ActsAsTenant.current_tenant = @ws
    @type   = create(:room_type, workspace: @ws, default_capacity: 1)
    @branch = create(:branch, workspace: @ws)
    # Cơ sở mở 09:00–21:00 mọi ngày.
    (0..6).each do |wd|
      @branch.branch_hours.create!(workspace: @ws, weekday: wd,
                                   opens_at: "09:00", closes_at: "21:00")
    end
    @room   = create(:room, workspace: @ws, branch: @branch, room_type: @type, capacity: 1,
                     turnaround_minutes: 15)
    @staff  = create(:staff_member, workspace: @ws, branch: @branch, gender: "female")
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 400_000)
    @date = Date.current + 2 # đủ xa để không vướng lead time
    shift(@staff, @date, 9, 21)
  end

  def teardown
    ActsAsTenant.current_tenant = nil
  end

  def shift(staff, date, from_h, to_h)
    @ws.staff_shifts.create!(staff_member: staff, branch: @branch, work_date: date, kind: "shift",
                             starts_at: Time.zone.local(date.year, date.month, date.day, from_h),
                             ends_at:   Time.zone.local(date.year, date.month, date.day, to_h))
  end

  def at(hour, min = 0)
    Time.zone.local(@date.year, @date.month, @date.day, hour, min)
  end

  def finder(**kwargs)
    SlotFinder.new(branch: @branch, service: @service, **kwargs)
  end

  # ---- Giờ mở cửa --------------------------------------------------------
  test "slots stay inside opening hours and leave room for the full service" do
    slots = finder.slots_on(@date)
    assert slots.any?
    assert_equal at(9), slots.first.starts_at
    assert_equal at(20), slots.last.starts_at, "60′ cuối phải kết thúc đúng lúc đóng cửa 21:00"
  end

  test "a closed day offers nothing" do
    @branch.branch_hours.where(weekday: @date.wday).update_all(closed: true)
    assert_empty finder.slots_on(@date)
  end

  test "a branch closure day offers nothing" do
    @branch.branch_closures.create!(workspace: @ws, starts_on: @date, ends_on: @date, reason: "Nghỉ lễ")
    assert_empty finder.slots_on(@date)
  end

  test "a partial closure removes only the closed hours" do
    @branch.branch_closures.create!(workspace: @ws, starts_on: @date, ends_on: @date,
                                    starts_at: "12:00", ends_at: "14:00", reason: "Bảo trì")
    times = finder.slots_on(@date).map { |s| s.starts_at.strftime("%H:%M") }
    assert_includes times, "11:00"
    assert_not_includes times, "12:00"
    assert_not_includes times, "13:00"
    assert_includes times, "14:00"
  end

  # ---- Ca làm của KTV ----------------------------------------------------
  test "a service needing a therapist offers nothing when nobody is on shift" do
    @ws.staff_shifts.destroy_all
    assert_empty finder.slots_on(@date)
  end

  test "slots are limited to the hours the therapist actually works" do
    @ws.staff_shifts.destroy_all
    shift(@staff, @date, 14, 18)
    times = finder.slots_on(@date).map { |s| s.starts_at.strftime("%H:%M") }
    assert_equal "14:00", times.first
    assert_equal "17:00", times.last
  end

  test "approved leave carves its hours out of the shift" do
    @ws.staff_shifts.create!(staff_member: @staff, branch: @branch, work_date: @date, kind: "leave",
                             starts_at: at(9), ends_at: at(13), note: "Nghỉ sáng")
    times = finder.slots_on(@date).map { |s| s.starts_at.strftime("%H:%M") }
    assert_not_includes times, "09:00"
    assert_includes times, "13:00"
  end

  # ---- Phòng & dọn phòng --------------------------------------------------
  test "a booked hour blocks the room, and so does the turnaround after it" do
    book_at(at(10))
    times = finder.slots_on(@date).map { |s| s.starts_at.strftime("%H:%M") }
    assert_not_includes times, "10:00", "giờ đã có khách"
    assert_not_includes times, "10:30", "chồng lên lượt đang chạy"
    assert_not_includes times, "11:00", "11:00–11:15 còn là thời gian dọn phòng"
    assert_includes times, "11:15", "dọn xong 15′ thì nhận khách tiếp"
  end

  test "a multi-seat room keeps selling until its capacity is used up" do
    @room.update!(capacity: 3, turnaround_minutes: 0)
    # Mỗi chỗ vẫn cần một KTV, nên khu 3 ghế chỉ bán được 3 lượt khi có 3 KTV.
    2.times do
      extra = create(:staff_member, workspace: @ws, branch: @branch)
      shift(extra, @date, 9, 21)
    end
    3.times { book_at(at(10)) }
    assert_not_includes finder.slots_on(@date).map { |s| s.starts_at }, at(10),
                        "hết cả 3 ghế thì không còn slot 10:00"
  end

  test "a room seat frees up even when the therapist pool is the real limit" do
    @room.update!(capacity: 4, turnaround_minutes: 0)
    book_at(at(10))
    # Chỉ có 1 KTV: ghế còn trống nhưng không còn người làm → không bán nữa.
    assert_not_includes finder.slots_on(@date).map { |s| s.starts_at }, at(10)
  end

  test "a cancelled booking frees the room again" do
    b = book_at(at(10))
    b.transition_to!("cancelled")
    assert_includes finder.slots_on(@date).map { |s| s.starts_at }, at(10)
  end

  test "a service only fits rooms of the types it declares" do
    other = create(:room_type, workspace: @ws)
    @service.update!(room_type_ids: [other.id])
    assert_empty finder.slots_on(@date), "không có phòng loại phù hợp thì không có slot"
    create(:room, workspace: @ws, branch: @branch, room_type: other, capacity: 1)
    assert finder.slots_on(@date).any?
  end

  test "a room under maintenance is not offered" do
    @room.update!(status: "maintenance")
    assert_empty finder.slots_on(@date)
  end

  # ---- KTV chỉ định & giới tính -------------------------------------------
  test "asking for a specific therapist only returns that therapist's free hours" do
    other = create(:staff_member, workspace: @ws, branch: @branch)
    shift(other, @date, 9, 21)
    @room.update!(capacity: 2, turnaround_minutes: 0)
    book_at(at(10), staff: @staff)
    times = finder(staff: @staff).slots_on(@date).map { |s| s.starts_at.strftime("%H:%M") }
    assert_not_includes times, "10:00", "KTV được chỉ định đang có khách"
    assert_includes finder(staff: other).slots_on(@date).map { |s| s.starts_at.strftime("%H:%M") }, "10:00"
  end

  test "a gender preference filters the therapist pool" do
    assert finder(gender: "Nữ").slots_on(@date).any?
    assert_empty finder(gender: "Nam").slots_on(@date), "không có KTV nam thì không có slot"
  end

  # ---- Đi hai người --------------------------------------------------------
  test "a couple booking needs two free therapists and two seats" do
    @room.update!(capacity: 2, turnaround_minutes: 0)
    assert_empty finder(party_size: 2).slots_on(@date), "chỉ có 1 KTV thì không nhận 2 khách"
    second = create(:staff_member, workspace: @ws, branch: @branch)
    shift(second, @date, 9, 21)
    assert SlotFinder.new(branch: @branch, service: @service, party_size: 2).slots_on(@date).any?
  end

  # ---- Lead time & chân trời ---------------------------------------------
  test "slots inside the minimum lead time are hidden" do
    today = Date.current
    shift(@staff, today, 0, 23)
    @branch.update_branch_settings!("booking_lead_minutes" => 120)
    slots = SlotFinder.new(branch: @branch, service: @service).slots_on(today)
    assert slots.all? { |s| s.starts_at >= Time.current + 119.minutes },
           "không được chào giờ sát hơn thời gian đặt trước tối thiểu"
  end

  test "the front desk can place a walk-in right now, ignoring lead time" do
    today = Date.current
    shift(@staff, today, 0, 23)
    @branch.update_branch_settings!("booking_lead_minutes" => 120)
    slots = SlotFinder.new(branch: @branch, service: @service, ignore_lead_time: true).slots_on(today)
    assert slots.any? { |s| s.starts_at < Time.current + 120.minutes }
  end

  test "a held slot is treated as taken until the hold expires" do
    BookingHold.place!(workspace: @ws, branch: @branch, room: @room, staff: @staff,
                       starts_at: at(10), ends_at: at(11))
    assert_not_includes finder.slots_on(@date).map { |s| s.starts_at }, at(10)
    BookingHold.update_all(expires_at: 1.minute.ago)
    assert_includes finder.slots_on(@date).map { |s| s.starts_at }, at(10)
  end

  private

  def book_at(time, staff: nil)
    res = BookingScheduler.create(
      branch: @branch, starts_at: time, source: "staff", guest_name: "Khách test",
      lines: [{ service: @service, staff: staff }]
    )
    assert res.ok?, "không đặt được lịch nền: #{res.error}"
    res.booking
  end
end

# Giá hứa với khách phải bằng giá ghi vào lịch hẹn — sai chỗ này là mất niềm tin
# ngay ở lần đầu khách dùng app.
class BookingPricingTest < ActiveSupport::TestCase
  def setup
    @ws = create(:workspace)
    ActsAsTenant.current_tenant = @ws
    @branch = create(:branch, workspace: @ws)
    (0..6).each { |wd| @branch.branch_hours.create!(workspace: @ws, weekday: wd, opens_at: "09:00", closes_at: "21:00") }
    create(:room, workspace: @ws, branch: @branch, capacity: 4, turnaround_minutes: 0)
    @level = create(:staff_level, workspace: @ws, surcharge: 100_000)
    @premium = create(:staff_member, workspace: @ws, branch: @branch, staff_level: @level)
    @plain   = create(:staff_member, workspace: @ws, branch: @branch)
    @service = create(:service, workspace: @ws, duration_minutes: 60, price: 500_000)
    @date = Date.current + 2
    [@premium, @plain].each do |s|
      @ws.staff_shifts.create!(staff_member: s, branch: @branch, work_date: @date, kind: "shift",
                               starts_at: Time.zone.local(@date.year, @date.month, @date.day, 9),
                               ends_at:   Time.zone.local(@date.year, @date.month, @date.day, 21))
    end
    @at = Time.zone.local(@date.year, @date.month, @date.day, 10)
  end

  def teardown
    ActsAsTenant.current_tenant = nil
  end

  test "picking a premium therapist adds their level surcharge" do
    res = BookingScheduler.create(branch: @branch, starts_at: @at, guest_name: "Khách",
                                  lines: [{ service: @service, staff: @premium }])
    assert res.ok?, res.error
    assert_equal 600_000, res.booking.estimated_total
  end

  test "letting the spa choose never charges a premium the guest did not pick" do
    # Chỉ còn KTV hạng cao rảnh, nhưng khách bấm "spa tự xếp" → không thu phụ thu.
    @ws.staff_shifts.where(staff_member_id: @plain.id).destroy_all
    res = BookingScheduler.create(branch: @branch, starts_at: @at, guest_name: "Khách",
                                  lines: [{ service: @service }])
    assert res.ok?, res.error
    assert_equal @premium.id, res.booking.booking_items.first.staff_member_id
    assert_equal 500_000, res.booking.estimated_total,
                 "khách không chọn KTV hạng cao thì không được thu phụ thu"
  end

  test "the member tier discount is written onto the booking, not just shown" do
    tier = create(:member_tier, workspace: @ws, discount_percent: 10)
    member = create(:member, workspace: @ws, member_tier: tier)
    res = BookingScheduler.create(branch: @branch, starts_at: @at, member: member,
                                  lines: [{ service: @service, staff: @premium }])
    assert res.ok?, res.error
    # 500k + 100k phụ thu = 600k, giảm 10% = 60k → 540k
    assert_equal 60_000, res.booking.booking_items.sum(&:discount_amount)
    assert_equal 540_000, res.booking.estimated_total
  end

  test "the discount splits across every line and the total stays exact" do
    tier = create(:member_tier, workspace: @ws, discount_percent: 15)
    member = create(:member, workspace: @ws, member_tier: tier)
    addon = create(:service, workspace: @ws, name: "Giác hơi", duration_minutes: 20,
                   price: 150_000, is_addon: true, requires_room: false, requires_staff: false)
    res = BookingScheduler.create(branch: @branch, starts_at: @at, member: member,
                                  lines: [{ service: @service, addons: [addon] }])
    assert res.ok?, res.error
    b = res.booking
    subtotal = b.booking_items.sum { |i| i.price + i.staff_surcharge }
    expected_off = (subtotal * 0.15).round(-3)
    assert_equal expected_off, b.booking_items.sum(&:discount_amount),
                 "tổng giảm giá chia về các lượt phải khớp đúng con số đã hứa"
    assert_equal subtotal - expected_off, b.estimated_total
  end
end
