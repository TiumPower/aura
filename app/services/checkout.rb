# Thu ngân. Mọi thay đổi về tiền của một bill đi qua đây, nên hoa hồng, điểm
# thưởng, ví và thẻ liệu trình không bao giờ lệch nhau.
#
# Vòng đời: mở bill → thêm/bớt dòng → thu tiền → ĐÓNG BILL. Chỉ khi đóng bill
# mới thật sự trừ buổi trong thẻ, cộng điểm và sinh hoa hồng — trước đó khách
# còn có thể đổi ý, và một buổi bị trừ oan là việc rất khó giải thích.
class Checkout
  class Error < StandardError; end

  Result = Struct.new(:order, :error, keyword_init: true) do
    def ok? = error.nil?
  end

  # ---- Mở bill -----------------------------------------------------------
  # Mở bill từ một lịch hẹn: kéo sẵn các lượt dịch vụ kèm KTV thực hiện, và
  # nếu khách có thẻ liệu trình còn buổi cho đúng dịch vụ thì đánh dấu trừ buổi
  # ngay (lễ tân vẫn bỏ được nếu khách muốn trả tiền).
  def self.open_for_booking(booking:, actor: nil)
    existing = booking.workspace.orders.find_by(booking_id: booking.id, status: "open")
    return Result.new(order: existing) if existing

    order = nil
    Order.transaction do
      order = booking.workspace.orders.create!(
        branch: booking.branch, member: booking.member, booking: booking,
        cashier: (actor.is_a?(User) ? actor : nil), status: "open"
      )
      booking.booking_items.live.ordered.each do |item|
        credit = booking.member && usable_credit(booking.member, item.service, item.service_variant)
        order.order_items.create!(
          workspace: order.workspace, kind: item.parent_item_id ? "addon" : "service",
          service: item.service, booking_item: item, staff_member: item.staff_member,
          name: item.service_label, quantity: 1,
          unit_price: item.price.to_i + item.staff_surcharge.to_i,
          # Dòng trả bằng buổi trong thẻ thì KHÔNG mang theo giảm giá: khách đã
          # trả tiền lúc mua thẻ, giữ lại con số giảm giá chỉ làm phồng chỉ số
          # "đã giảm bao nhiêu" của spa.
          discount_amount: credit ? 0 : item.discount_amount.to_i,
          package_credit: credit
        )
      end
      order.recalculate!
    end
    Result.new(order: order)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(error: e.record.errors.full_messages.to_sentence)
  end

  # Mở bill trắng (khách chỉ mua hàng / nạp ví / mua thẻ, không có lịch hẹn).
  def self.open_blank(branch:, member: nil, actor: nil)
    order = branch.workspace.orders.create!(
      branch: branch, member: member, cashier: (actor.is_a?(User) ? actor : nil), status: "open"
    )
    Result.new(order: order)
  end

  def self.usable_credit(member, service, variant = nil)
    member.member_packages.usable.recent.each do |mp|
      credit = mp.credit_for(service, variant)
      return credit if credit
    end
    nil
  end

  # ---- Sửa bill ----------------------------------------------------------
  def self.add_service(order:, service:, variant: nil, staff: nil, use_package: true)
    credit = use_package && order.member ? usable_credit(order.member, service, variant) : nil
    order.order_items.create!(
      workspace: order.workspace, kind: service.is_addon? ? "addon" : "service",
      service: service, staff_member: staff,
      name: variant ? "#{service.name} #{variant.name}" : service.name,
      quantity: 1, unit_price: service.price_for(variant, branch: order.branch),
      package_credit: credit
    )
    order.recalculate!
  end

  # Bán thẻ liệu trình / thẻ tiền. Thẻ chỉ được TẠO khi bill đóng, nên ở đây chỉ
  # ghi dòng tiền và ghi nhớ ai là người chốt thẻ (để tính hoa hồng tư vấn).
  def self.add_package(order:, package:, consultant: nil)
    order.order_items.create!(
      workspace: order.workspace, kind: "package", package: package,
      consultant: consultant, name: package.name, quantity: 1, unit_price: package.price,
      meta: { "kind" => package.kind }
    )
    order.recalculate!
  end

  def self.add_topup(order:, amount:, consultant: nil)
    bonus_percent = order.branch.setting_i("wallet_topup_bonus_percent")
    order.order_items.create!(
      workspace: order.workspace, kind: "topup", consultant: consultant,
      name: "Nạp ví trả trước", quantity: 1, unit_price: amount.to_i,
      meta: { "bonus_percent" => bonus_percent }
    )
    order.recalculate!
  end

  def self.add_tip(order:, amount:, staff:)
    order.order_items.create!(
      workspace: order.workspace, kind: "tip", staff_member: staff,
      name: "Tip cho #{staff&.display_name || 'KTV'}", quantity: 1, unit_price: amount.to_i
    )
    order.recalculate!
  end

  def self.add_fee(order:, name:, amount:)
    order.order_items.create!(workspace: order.workspace, kind: "fee", name: name,
                              quantity: 1, unit_price: amount.to_i)
    order.recalculate!
  end

  def self.remove_item(order:, item:)
    item.destroy
    order.recalculate!
  end

  # Giảm giá cả bill: chia về từng dòng để mọi báo cáo doanh thu theo dịch vụ
  # vẫn đúng (giảm giá treo ở cấp bill sẽ làm doanh thu từng dịch vụ bị phóng đại).
  def self.apply_discount(order:, amount: nil, percent: nil, note: nil)
    lines = order.order_items.reject { |i| i.kind == "tip" || i.from_package? }
    base = lines.sum { |i| i.unit_price.to_i * i.quantity.to_i }
    return order.recalculate! if base.zero?

    total_off = percent.present? ? (base * percent.to_f / 100).round(-3) : amount.to_i
    total_off = [total_off, base].min
    remaining = total_off
    lines.each_with_index do |item, idx|
      line_base = item.unit_price.to_i * item.quantity.to_i
      off = idx == lines.size - 1 ? remaining : (total_off * line_base / base.to_f).round(-3)
      off = [off, remaining].min
      item.update!(discount_amount: off)
      remaining -= off
    end
    order.update!(discount_note: note)
    order.recalculate!
  end

  # ---- Thu tiền ----------------------------------------------------------
  def self.pay(order:, method:, amount:, reference: nil, actor: nil, note: nil)
    amount = amount.to_i
    return Result.new(order: order, error: "Số tiền không hợp lệ.") if amount <= 0

    Order.transaction do
      case method
      when "wallet"
        raise Error, "Bill chưa gắn khách nên không dùng được ví." if order.member.nil?
        raise Error, "Ví chỉ còn #{order.member.wallet_balance}đ." if order.member.wallet_balance.to_i < amount
        WalletTransaction.record!(member: order.member, kind: "spend", amount: -amount,
                                  order: order, note: "Thanh toán bill #{order.code}", actor: actor)
      when "points"
        raise Error, "Bill chưa gắn khách nên không đổi được điểm." if order.member.nil?
        value = order.branch.setting_i("points_value")
        raise Error, "Spa chưa đặt giá trị quy đổi điểm." if value <= 0
        points = (amount.to_f / value).ceil
        min = order.branch.setting_i("points_redeem_min")
        raise Error, "Cần tối thiểu #{min} điểm để đổi." if min.positive? && points < min
        raise Error, "Khách chỉ có #{order.member.points_balance} điểm." if order.member.points_balance.to_i < points
        PointTransaction.record!(member: order.member, kind: "redeem", points: -points,
                                 order: order, note: "Đổi điểm trừ bill #{order.code}", actor: actor)
        order.update!(points_redeemed: order.points_redeemed.to_i + points)
      end

      order.order_payments.create!(
        workspace: order.workspace, method: method, amount: amount,
        reference: reference, received_by: (actor.is_a?(User) ? actor : nil),
        received_at: Time.current, note: note
      )
      order.recalculate!
    end
    Result.new(order: order)
  rescue Error, ArgumentError => e
    Result.new(order: order, error: e.message)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(order: order, error: e.record.errors.full_messages.to_sentence)
  end

  # ---- Đóng bill ---------------------------------------------------------
  # Đây là thời điểm DUY NHẤT tiền, buổi, điểm và hoa hồng được chốt.
  def self.close!(order:, actor: nil)
    return Result.new(order: order, error: "Bill đã đóng.") unless order.open?
    order.recalculate!
    if order.due.positive?
      return Result.new(order: order, error: "Còn thiếu #{ActiveSupport::NumberHelper.number_to_delimited(order.due)}đ.")
    end
    if order.branch.setting?("treatment_record_required") && order.booking && !record_written?(order.booking)
      return Result.new(order: order, error: "Cần ghi hồ sơ điều trị trước khi đóng bill (theo thiết lập của spa).")
    end

    Order.transaction do
      consume_package_credits!(order, actor: actor)
      issue_packages!(order, actor: actor)
      apply_topups!(order, actor: actor)
      award_points!(order, actor: actor)
      record_commissions!(order)
      order.update!(status: "paid", closed_at: Time.current,
                    cashier: order.cashier || (actor.is_a?(User) ? actor : nil))
      update_member_totals!(order)
      complete_booking!(order, actor: actor)
    end
    Result.new(order: order)
  rescue Error, ArgumentError => e
    Result.new(order: order, error: e.message)
  end

  # Huỷ bill đã đóng: nhả lại buổi, ví, điểm và hoa hồng. Không xoá bill —
  # xoá là mất dấu, mà tranh chấp tiền luôn cần dấu.
  def self.void!(order:, actor: nil, reason: nil)
    Order.transaction do
      if order.paid?
        restore_package_credits!(order, actor: actor)
        refund_wallet_and_points!(order, actor: actor)
        order.commission_entries.destroy_all
        if order.member
          order.member.update!(total_spent: [order.member.total_spent.to_i - order.total.to_i, 0].max)
        end
      end
      order.update!(status: "void", voided_at: Time.current, void_reason: reason,
                    voided_by_id: (actor.is_a?(User) ? actor.id : nil))
    end
    Result.new(order: order)
  rescue Error, ArgumentError => e
    Result.new(order: order, error: e.message)
  end

  # ---- Bên trong ---------------------------------------------------------
  def self.record_written?(booking)
    return true unless defined?(TreatmentNote)
    TreatmentNote.where(booking_id: booking.id).exists?
  end

  def self.consume_package_credits!(order, actor: nil)
    order.order_items.select(&:from_package?).each do |item|
      credit = item.package_credit
      if credit.nil? || credit.remaining.zero?
        raise Error, "Thẻ liệu trình cho “#{item.name}” đã hết buổi — hãy bỏ trừ buổi ở dòng đó."
      end
      credit.consume!(booking_item: item.booking_item, order_item: item,
                      staff: item.staff_member, actor: actor, reason: "Bill #{order.code}")
    end
  end

  def self.restore_package_credits!(order, actor: nil)
    order.order_items.select(&:from_package?).each do |item|
      item.package_credit&.restore!(actor: actor, reason: "Huỷ bill #{order.code}")
    end
  end

  # Bán thẻ: tạo thẻ THẬT cho khách khi bill đóng.
  def self.issue_packages!(order, actor: nil)
    order.order_items.where(kind: "package").each do |item|
      pkg = item.package
      next if pkg.nil? || order.member.nil?
      mp = order.member.member_packages.create!(
        workspace: order.workspace, package: pkg, order: order, sold_by: item.consultant,
        name: pkg.name, kind: pkg.kind, price_paid: item.total,
        value_balance: pkg.value_card? ? pkg.face : 0,
        purchased_on: Date.current,
        expires_on: pkg.validity.positive? ? Date.current + pkg.validity.days : nil
      )
      pkg.package_lines.each do |line|
        mp.package_credits.create!(workspace: order.workspace, service: line.service,
                                   service_variant: line.service_variant,
                                   total_sessions: line.sessions, used_sessions: 0)
      end
    end
  end

  def self.apply_topups!(order, actor: nil)
    order.order_items.where(kind: "topup").each do |item|
      next if order.member.nil?
      WalletTransaction.record!(member: order.member, kind: "topup", amount: item.total,
                                order: order, note: "Nạp ví · bill #{order.code}", actor: actor)
      bonus_percent = item.meta["bonus_percent"].to_i
      next unless bonus_percent.positive?
      bonus = (item.total * bonus_percent / 100.0).round(-3)
      next if bonus.zero?
      WalletTransaction.record!(member: order.member, kind: "bonus", amount: bonus,
                                order: order, note: "Thưởng nạp ví #{bonus_percent}%", actor: actor)
    end
  end

  def self.award_points!(order, actor: nil)
    return if order.member.nil?
    per = order.branch.setting_i("points_per_1000_spent")
    return if per.zero?
    # Dòng trả bằng buổi trong thẻ không sinh điểm (khách đã tích điểm lúc mua thẻ).
    spend = order.order_items.reject { |i| i.from_package? || i.kind == "tip" }.sum(&:total)
    return if spend <= 0
    multiplier = order.member.member_tier&.points_multiplier || 1
    points = ((spend / 1000.0) * per * multiplier).floor
    return if points <= 0
    PointTransaction.record!(member: order.member, kind: "earn", points: points,
                             order: order, note: "Bill #{order.code}", actor: actor)
    order.update!(points_earned: points)
  end

  # Hoa hồng: KTV làm dịch vụ, người chốt thẻ, và tip.
  def self.record_commissions!(order)
    return unless order.workspace.feature?("commissions")
    order.order_items.each do |item|
      case item.kind
      when "service", "addon"
        staff = item.staff_member
        next if staff.nil?
        # Dòng trả bằng buổi trong thẻ vẫn tính hoa hồng cho KTV: họ đã làm việc,
        # dù tiền đã thu từ lúc bán thẻ. Lấy giá niêm yết làm gốc.
        base = item.from_package? ? item.unit_price.to_i : commission_base(item, order)
        rate = item.service&.commission_rate_for(staff) || staff.commission_rate
        amount = (base * rate / 100.0).round(-2)
        next if amount.zero?
        entry = order.commission_entries.create!(
          workspace: order.workspace, staff_member: staff, order_item: item,
          role: "therapist", basis: "percent", base_amount: base, rate: rate,
          amount: amount, earned_on: Date.current
        )
        item.update!(commission_amount: entry.amount)
      when "package", "topup"
        consultant = item.consultant
        next if consultant.nil?
        rate = item.package&.commission_rate || order.workspace.setting_i("consultant_commission_percent")
        amount = (item.total * rate / 100.0).round(-2)
        next if amount.zero?
        order.commission_entries.create!(
          workspace: order.workspace, staff_member: consultant, order_item: item,
          role: "consultant", basis: "percent", base_amount: item.total, rate: rate,
          amount: amount, earned_on: Date.current
        )
      when "tip"
        staff = item.staff_member
        next if staff.nil?
        share = order.workspace.setting_i("tip_to_staff_percent")
        amount = (item.total * share / 100.0).round(-2)
        next if amount.zero?
        order.commission_entries.create!(
          workspace: order.workspace, staff_member: staff, order_item: item,
          role: "therapist", basis: "tip", base_amount: item.total, rate: share,
          amount: amount, earned_on: Date.current
        )
      end
    end
  end

  # Gốc tính hoa hồng: net (sau giảm giá) hay gross (giá niêm yết) — do spa chọn.
  def self.commission_base(item, order)
    order.workspace.setting("commission_basis") == "gross" ?
      item.unit_price.to_i * item.quantity.to_i : item.total.to_i
  end

  def self.update_member_totals!(order)
    m = order.member
    return if m.nil?
    m.update!(total_spent: m.total_spent.to_i + order.total.to_i)
    m.refresh_tier!
  end

  def self.complete_booking!(order, actor: nil)
    b = order.booking
    return if b.nil?
    b.transition_to!("completed", actor: actor) if b.can_transition_to?("completed")
  end

  def self.refund_wallet_and_points!(order, actor: nil)
    order.order_payments.where(method: "wallet").each do |p|
      WalletTransaction.record!(member: order.member, kind: "refund", amount: p.amount,
                                order: order, note: "Hoàn ví do huỷ bill #{order.code}", actor: actor)
    end
    if order.points_redeemed.to_i.positive? && order.member
      PointTransaction.record!(member: order.member, kind: "adjust", points: order.points_redeemed,
                               order: order, note: "Hoàn điểm do huỷ bill #{order.code}", actor: actor)
    end
    if order.points_earned.to_i.positive? && order.member
      PointTransaction.record!(member: order.member, kind: "adjust", points: -order.points_earned,
                               order: order, note: "Thu hồi điểm do huỷ bill #{order.code}", actor: actor)
    end
  end
end
