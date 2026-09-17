# Engine tìm chỗ trống. Đây là nơi duy nhất trả lời câu "15h30 mai còn nhận
# được khách không" — cả quầy lễ tân và app khách đều đi qua đây, nên không có
# đường nào tạo ra lịch đụng nhau.
#
# Một slot chỉ hợp lệ khi ĐỒNG THỜI:
#   1. nằm trong giờ mở cửa của cơ sở hôm đó (đã trừ ngày nghỉ / đóng cửa)
#   2. có phòng đúng loại còn chỗ, tính cả thời gian DỌN PHÒNG của lượt trước
#   3. có đủ KTV rảnh (đang trong ca, không nghỉ phép, không trùng lượt khác)
#   4. không bị một chỗ đang giữ tạm (booking_hold) chiếm
#   5. thoả thời gian đặt trước tối thiểu và chân trời đặt trước
#
# KHÔNG đặt trong module `Booking::` — tên đó va với model Booking dưới Zeitwerk.
class SlotFinder
  Slot = Struct.new(:starts_at, :ends_at, :room, :staff, :staff_list, keyword_init: true) do
    def to_param = starts_at.strftime("%H:%M")
    def label    = starts_at.strftime("%H:%M")
  end

  attr_reader :branch, :service, :variant, :party_size

  def initialize(branch:, service:, variant: nil, staff: nil, gender: nil,
                 party_size: 1, exclude_booking: nil, ignore_lead_time: false)
    @branch  = branch
    @service = service
    @variant = variant
    @staff   = staff              # KTV khách chỉ định (nil = bất kỳ)
    @gender  = gender.presence     # "Nữ" / "Nam" — khách chọn giới tính KTV
    @party_size = [party_size.to_i, 1].max
    @exclude_booking = exclude_booking # khi đổi giờ một lịch đã có
    @ignore_lead_time = ignore_lead_time # quầy xếp tay thì không áp lead time
  end

  def workspace = branch.workspace
  def duration  = service.duration_for(variant)

  # Các slot còn nhận được khách trong MỘT ngày.
  def slots_on(date)
    return [] unless date.is_a?(Date)
    windows = branch.open_windows(date)
    return [] if windows.empty?

    step = [branch.setting_i("slot_step_minutes"), 5].max
    earliest = @ignore_lead_time ? Time.current.beginning_of_day
                                 : Time.current + branch.setting_i("booking_lead_minutes").minutes
    latest = Time.current + branch.setting_i("booking_horizon_days").days

    rooms = candidate_rooms
    staff = candidate_staff(date)
    return [] if service.requires_room? && rooms.empty?
    return [] if service.requires_staff? && staff.size < party_size

    found = []
    windows.each do |(open_at, close_at)|
      t = round_up(open_at, step)
      while t + duration.minutes <= close_at
        if t >= earliest && t <= latest
          slot = try_slot(t, rooms: rooms, staff: staff)
          found << slot if slot
        end
        t += step.minutes
      end
    end
    found
  end

  # Ngày nào trong khoảng còn chỗ — dùng cho bộ chọn ngày trên app khách.
  def open_days(from: Date.current, days: 14)
    (from..(from + days - 1)).select { |d| slots_on(d).any? }
  end

  # Thử xếp đúng một mốc giờ. Trả về Slot nếu được, nil nếu không.
  def try_slot(at, rooms: nil, staff: nil)
    rooms ||= candidate_rooms
    staff ||= candidate_staff(at.to_date)
    finish = at + duration.minutes
    buffer = service.buffer_for

    room = nil
    if service.requires_room?
      room = rooms.find { |r| room_free?(r, at, finish, buffer) }
      return nil if room.nil?
    end

    chosen = []
    if service.requires_staff?
      needed = party_size * [service.staff_count, 1].max
      chosen = staff.select { |s| staff_free?(s, at, finish) }.first(needed)
      return nil if chosen.size < needed
    end

    Slot.new(starts_at: at, ends_at: finish, room: room,
             staff: chosen.first, staff_list: chosen)
  end

  # ---- Ứng viên ----------------------------------------------------------
  def candidate_rooms
    @candidate_rooms ||= begin
      rows = branch.rooms.active.ordered.to_a
      rows = rows.select { |r| service.accepts_room?(r) } if service.requires_room?
      # Phòng khách chọn được xếp trước; phòng chỉ dành cho quầy vẫn dùng khi
      # quầy xếp tay (ignore_lead_time = quầy).
      @ignore_lead_time ? rows : rows.select(&:online_bookable)
    end
  end

  def candidate_staff(date)
    @candidate_staff ||= {}
    @candidate_staff[date] ||= begin
      rows = workspace.staff_members.active.therapists.at_branch(branch.id).ordered.to_a
      rows = rows.select(&:online_bookable) unless @ignore_lead_time
      rows = rows.select { |s| s.id == @staff.id } if @staff
      if @gender && branch.setting?("allow_gender_preference")
        want = { "Nữ" => "female", "Nam" => "male" }[@gender] || @gender
        rows = rows.select { |s| s.gender == want }
      end
      if (capable = service.capable_staff_ids)
        rows = rows.select { |s| capable.include?(s.id) }
      end
      # Chỉ giữ KTV có ca làm phủ ĐỦ khoảng cần thiết trong ngày đó.
      rows.select { |s| s.work_windows(date).any? }
    end
  end

  # ---- Kiểm tra trùng ----------------------------------------------------
  # Phòng còn chỗ: số lượt đang chiếm (tính cả dọn phòng) phải nhỏ hơn capacity.
  def room_free?(room, from, to, buffer)
    return true if branch.setting?("overbook_allowed")
    window_to = to + buffer.minutes
    taken = BookingItem.room_busy(room.id, from, window_to)
    taken = taken.where.not(booking_id: @exclude_booking.id) if @exclude_booking
    used = taken.joins(:booking).where(bookings: { status: Booking::LIVE_STATUSES }).count
    used += BookingHold.room_busy(room.id, from, window_to).count
    used + party_size <= room.capacity
  end

  # KTV rảnh: đang trong ca phủ đủ khoảng, và không trùng lượt nào khác.
  def staff_free?(staff, from, to)
    return false unless staff.work_windows(from.to_date).any? { |(ws, we)| ws <= from && we >= to }
    busy = BookingItem.staff_busy(staff.id, from, to)
    busy = busy.where.not(booking_id: @exclude_booking.id) if @exclude_booking
    return false if busy.joins(:booking).where(bookings: { status: Booking::LIVE_STATUSES }).exists?
    return false if BookingHold.staff_busy(staff.id, from, to).exists?
    true
  end

  private

  def round_up(time, step)
    secs = step * 60
    Time.zone.at(((time.to_i + secs - 1) / secs) * secs)
  end
end
