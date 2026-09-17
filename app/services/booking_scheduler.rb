# Tạo / đổi giờ / huỷ lịch hẹn. Mọi đường vào (quầy lễ tân, app khách, khách
# vãng lai) đều đi qua đây để luật xếp chỗ chỉ nằm ở MỘT nơi.
#
# Điểm quan trọng: kiểm tra trùng được chạy LẠI bên trong transaction ngay
# trước khi ghi. Chỗ giữ tạm (BookingHold) làm hẹp cửa sổ tranh chấp, nhưng chỉ
# lần kiểm tra cuối này mới đóng hẳn được nó.
class BookingScheduler
  class Conflict < StandardError; end

  Result = Struct.new(:booking, :error, keyword_init: true) do
    def ok? = error.nil?
  end

  def self.create(**kwargs) = new(**kwargs).create

  attr_reader :branch, :workspace

  # lines: [{ service:, variant:, staff:, room:, guest_label:, addons: [service, ...] }, ...]
  def initialize(branch:, starts_at:, lines:, member: nil, guest_name: nil, guest_phone: nil,
                 source: "staff", actor: nil, note: nil, internal_note: nil,
                 party_size: nil, gender: nil, hold_token: nil, status: nil)
    @branch    = branch
    @workspace = branch.workspace
    @starts_at = starts_at
    @lines     = Array(lines)
    @member    = member
    @guest_name  = guest_name
    @guest_phone = guest_phone
    @source    = source
    @actor     = actor
    @note      = note
    @internal_note = internal_note
    @party_size = party_size || @lines.map { |l| l[:guest_label] }.compact.uniq.size.clamp(1, 99)
    @gender    = gender
    @hold_token = hold_token
    @status    = status
  end

  def create
    return Result.new(error: "Chưa chọn dịch vụ nào.") if @lines.empty?
    return Result.new(error: "Khách này đang bị tạm chặn đặt lịch.") if blocked_member?

    booking = nil
    Booking.transaction do
      booking = @workspace.bookings.create!(
        branch: @branch, member: @member,
        guest_name: @guest_name, guest_phone: @guest_phone,
        status: initial_status, source: @source,
        starts_at: @starts_at, ends_at: @starts_at + 1.minute, # ghi lại sau khi có item
        party_size: @party_size, staff_gender_preference: @gender,
        note: @note, internal_note: @internal_note,
        created_by: (@actor.is_a?(User) ? @actor : nil)
      )
      place_lines!(booking)
      apply_tier_discount!(booking)
      booking.recalculate_total!
      release_hold!
    end
    Result.new(booking: booking)
  rescue Conflict => e
    Result.new(error: e.message)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(error: e.record.errors.full_messages.to_sentence)
  end

  # Đổi giờ một lịch đã có. Giữ nguyên dịch vụ, chỉ dịch toàn bộ khối giờ.
  def self.reschedule(booking:, starts_at:, actor: nil)
    delta = starts_at - booking.starts_at
    Booking.transaction do
      booking.booking_items.live.each do |item|
        new_from = item.starts_at + delta
        new_to   = item.ends_at + delta
        finder = SlotFinder.new(branch: booking.branch, service: item.service,
                                variant: item.service_variant, staff: item.staff_member,
                                exclude_booking: booking, ignore_lead_time: true)
        if item.room && !finder.room_free?(item.room, new_from, new_to, item.buffer_minutes)
          raise Conflict, "Phòng #{item.room.display_name} đã có khách vào giờ mới."
        end
        if item.staff_member && !finder.staff_free?(item.staff_member, new_from, new_to)
          raise Conflict, "#{item.staff_member.display_name} không rảnh vào giờ mới."
        end
        item.update!(starts_at: new_from, ends_at: new_to)
      end
      booking.update!(starts_at: starts_at)
      booking.recalculate_total!
    end
    Result.new(booking: booking)
  rescue Conflict => e
    Result.new(error: e.message)
  end

  private

  def blocked_member? = @member&.booking_blocked?

  # Lịch đặt online có thể cần quầy duyệt (tham số auto_confirm_online).
  def initial_status
    return @status if @status.present?
    return "confirmed" if %w[staff walk_in phone].include?(@source)
    @branch.setting?("auto_confirm_online") ? "confirmed" : "pending"
  end

  def place_lines!(booking)
    cursor_by_guest = {}
    @lines.each_with_index do |line, idx|
      service = line[:service]
      variant = line[:variant]
      label   = line[:guest_label].presence || "Khách #{idx + 1}"
      # Dịch vụ nối tiếp của CÙNG một khách bắt đầu sau khi lượt trước xong;
      # khách khác trong cùng lịch thì bắt đầu cùng giờ.
      from = cursor_by_guest[label] || @starts_at
      duration = service.duration_for(variant)
      to = from + duration.minutes
      buffer = service.buffer_for(line[:room])

      requested_staff = line[:staff]   # khách/quầy chỉ định đúng người này
      staff = requested_staff
      room  = line[:room]
      finder = SlotFinder.new(branch: @branch, service: service, variant: variant,
                              staff: staff, gender: @gender, party_size: 1,
                              ignore_lead_time: true)
      room ||= finder.candidate_rooms.find { |r| finder.room_free?(r, from, to, buffer) } if service.requires_room?
      if service.requires_room? && room.nil?
        raise Conflict, "Không còn phòng phù hợp cho #{service.name} lúc #{from.strftime('%H:%M')}."
      end
      if service.requires_room? && !finder.room_free?(room, from, to, buffer)
        raise Conflict, "Phòng #{room.display_name} đã có khách lúc #{from.strftime('%H:%M')}."
      end

      if service.requires_staff?
        staff ||= finder.candidate_staff(from.to_date).find { |s| finder.staff_free?(s, from, to) }
        raise Conflict, "Không còn KTV rảnh cho #{service.name} lúc #{from.strftime('%H:%M')}." if staff.nil?
        unless finder.staff_free?(staff, from, to)
          raise Conflict, "#{staff.display_name} không rảnh lúc #{from.strftime('%H:%M')}."
        end
      end

      item = booking.booking_items.create!(
        workspace: @workspace, service: service, service_variant: variant,
        staff_member: staff, room: room,
        starts_at: from, ends_at: to,
        duration_minutes: duration, buffer_minutes: buffer,
        price: service.price_for(variant, branch: @branch),
        # Phụ thu hạng KTV CHỈ tính khi khách tự chọn đúng người đó. Khách bấm
        # "spa tự xếp" rồi bị thu thêm vì hệ thống xếp một KTV hạng cao là thu
        # tiền cho thứ khách không chọn.
        staff_surcharge: requested_staff ? requested_staff.surcharge.to_i : 0,
        guest_label: label, position: idx
      )
      cursor_by_guest[label] = to

      # Addon đi kèm: chạy trong CÙNG phòng, cùng KTV, nối ngay sau lượt chính.
      Array(line[:addons]).each_with_index do |addon, ai|
        a_from = cursor_by_guest[label]
        a_to   = a_from + addon.duration_minutes.minutes
        booking.booking_items.create!(
          workspace: @workspace, service: addon, staff_member: staff, room: room,
          parent_item: item, starts_at: a_from, ends_at: a_to,
          duration_minutes: addon.duration_minutes,
          buffer_minutes: 0, price: addon.price_for(nil, branch: @branch),
          guest_label: label, position: idx * 100 + ai + 1
        )
        cursor_by_guest[label] = a_to
      end
    end
  end

  # Ưu đãi theo hạng thẻ của khách. Màn xác nhận đã hứa con số sau giảm giá, nên
  # lịch hẹn phải mang đúng con số đó — nếu không, khách ra quầy thấy giá khác.
  # Giảm giá tính trên TỔNG rồi chia về từng lượt, lượt cuối gánh phần lẻ, để
  # tổng khớp tuyệt đối với con số đã hứa.
  def apply_tier_discount!(booking)
    percent = @member&.tier_discount.to_i
    return if percent.zero?
    items = booking.booking_items.to_a
    subtotal = items.sum { |i| i.price.to_i + i.staff_surcharge.to_i }
    return if subtotal.zero?

    total_off = (subtotal * percent / 100.0).round(-3)
    remaining = total_off
    items.each_with_index do |item, idx|
      base = item.price.to_i + item.staff_surcharge.to_i
      off = idx == items.size - 1 ? remaining : (total_off * base / subtotal.to_f).round(-3)
      off = [off, remaining].min
      item.update!(discount_amount: off)
      remaining -= off
    end
  end

  def release_hold!
    return if @hold_token.blank?
    BookingHold.where(token: @hold_token).delete_all
  end
end
