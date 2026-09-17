# ---------------------------------------------------------------------------
# Aura — demo / test seed. Idempotent (safe to re-run).
# ---------------------------------------------------------------------------
require "faker"
Faker::Config.locale = "vi"

# ---------------------------------------------------------------------------
# Seed passwords
#
# The accounts below are real logins — the super admin sees every landlord, and
# the demo owner sees that landlord's tenants, bills and money. A password
# hard-coded here is a published credential: it lives in the repo and the emails
# are guessable. So outside development this file refuses to invent one.
#
#   development / test  → the convenience default (or SEED_PASSWORD if given)
#   anywhere else       → SEED_PASSWORD is required, and must be a real password
#
# Seeding is also non-destructive for credentials: a password is only ever set
# on an account this run CREATES. Re-running db:seed never resets a password
# someone has since changed.
# ---------------------------------------------------------------------------
DEV_SEED_PASSWORD = "aura1234".freeze
MIN_SEED_PASSWORD = 12

SEED_PASSWORD = begin
  given = ENV["SEED_PASSWORD"].presence
  if Rails.env.development? || Rails.env.test?
    given || DEV_SEED_PASSWORD
  elsif given.nil?
    abort <<~MSG
      ✗ Refusing to seed #{Rails.env}: SEED_PASSWORD is not set.

        This seed creates a super admin and a landlord owner. Using the built-in
        development password here would publish those logins — it is written in
        plain text in db/seeds.rb.

        Re-run with a password you choose, e.g.

          SEED_PASSWORD='<#{MIN_SEED_PASSWORD}+ characters>' bin/rails db:seed

        Existing accounts keep whatever password they already have.
    MSG
  elsif given.length < MIN_SEED_PASSWORD
    abort "✗ SEED_PASSWORD must be at least #{MIN_SEED_PASSWORD} characters (got #{given.length})."
  elsif given == DEV_SEED_PASSWORD
    abort "✗ SEED_PASSWORD must not be the development default."
  else
    given
  end
end

# Show the password only for an account this run just created, and only in
# development — printing it for an existing account would be a lie (it may have
# been changed since), and printing it in production would leak it to the log.
def seed_password_hint(created)
  return "" unless created && (Rails.env.development? || Rails.env.test?)
  " / #{SEED_PASSWORD}"
end

puts "Seeding Aura…"

Plan.seed_defaults!
puts "  ✓ Gói thuê bao: #{Plan.ordered.map(&:key).join(', ')}"

# ---- Super admin ----------------------------------------------------------
admin = AdminUser.find_or_initialize_by(email: "quocvietlee@gmail.com")
admin_created = admin.new_record?
if admin_created
  admin.assign_attributes(name: "Quốc Việt", role: "superadmin",
                          password: SEED_PASSWORD, password_confirmation: SEED_PASSWORD)
end
admin.save!
puts "  ✓ Super admin: quocvietlee@gmail.com#{seed_password_hint(admin_created)}"

# ---- Spa demo -------------------------------------------------------------
ws = Workspace.find_or_initialize_by(subdomain: "auraspa")
if ws.new_record?
  ws.assign_attributes(name: "Aura Spa Sài Gòn", status: "active", plan: "pro",
                       business_type: "mixed",
                       paid_until: 1.month.from_now.end_of_month,
                       theme: Workspace::THEME_PRESETS["jade"].except("name"),
                       branding: { "tagline" => "Trị liệu & thư giãn", "city" => "TP.HCM",
                                   "contact_phone" => "02838990099",
                                   "booking_note" => "Quý khách vui lòng đến trước 10 phút để thay đồ và dùng trà thảo mộc." })
  ws.save!
  WorkspaceBootstrap.call(ws)
  ws.update!(settings: ws.settings.merge(
    "onboarded" => true, "business_chosen" => true,
    "bank" => { "code" => "vietcombank", "bin" => "970436",
                "account_no" => "1023456789", "account_name" => "AURA SPA SAI GON" }
  ))
end
ws.update!(status: "active", plan: "pro", paid_until: 1.month.from_now.end_of_month) unless ws.active?

# Hoá đơn thuê bao nền tảng (để trang "Gói & thanh toán" có dữ liệu thật).
ActsAsTenant.with_tenant(ws) do
  if ws.invoices.count.zero?
    price = Plan.for(ws.plan).price
    (1..3).each do |i|
      m = Date.current.beginning_of_month - i.months
      ws.invoices.create!(plan: ws.plan, amount: price, status: "paid",
                          period_start: m, period_end: m.end_of_month, paid_at: m + 4.days)
    end
    cm = Date.current.beginning_of_month
    ws.invoices.create!(plan: ws.plan, amount: price, status: "pending",
                        period_start: cm, period_end: cm.end_of_month)
  end
end

owner = User.find_or_initialize_by(email: "chu@aura.local")
owner_created = owner.new_record?
if owner_created
  owner.assign_attributes(name: "Trần Minh Anh", locale: "vi", phone: "0909111222",
                          password: SEED_PASSWORD, password_confirmation: SEED_PASSWORD)
  owner.save!
end

reception = User.find_or_initialize_by(email: "letan@aura.local")
reception_created = reception.new_record?
if reception_created
  reception.assign_attributes(name: "Lê Thu Hà", locale: "vi",
                              password: SEED_PASSWORD, password_confirmation: SEED_PASSWORD)
  reception.save!
end

ActsAsTenant.with_tenant(ws) do
  ws.memberships.find_or_create_by!(user: owner) { |m| m.role = "owner" }

  # ---- Loại phòng / hạng KTV / hạng thẻ ---------------------------------
  RoomType.presets_for(ws.business_type).each_with_index do |attrs, i|
    ws.room_types.find_or_create_by!(key: attrs[:key]) { |t| t.assign_attributes(attrs.merge(position: i)) }
  end
  StaffLevel::PRESETS.each do |attrs|
    ws.staff_levels.find_or_create_by!(key: attrs[:key]) { |l| l.assign_attributes(attrs) }
  end
  MemberTier::PRESETS.each do |attrs|
    ws.member_tiers.find_or_create_by!(key: attrs[:key]) { |t| t.assign_attributes(attrs) }
  end

  types  = ws.room_types.index_by(&:key)
  levels = ws.staff_levels.index_by(&:key)
  tiers  = ws.member_tiers.index_by(&:key)

  # ---- Hai cơ sở --------------------------------------------------------
  branch_specs = [
    { name: "Aura Spa Phú Nhuận", code: "PN", phone: "02838990099",
      address_line: "128 Phan Xích Long", ward: "Phường 2", district: "Phú Nhuận", city: "TP.HCM",
      rooms: [["Khu foot A", "foot", 6], ["Phòng 1", "single", 1], ["Phòng 2", "single", 1],
              ["Phòng đôi VIP", "couple", 2], ["Phòng da 1", "facial", 1], ["Xông hơi", "sauna", 4]] },
    { name: "Aura Spa Thảo Điền", code: "TD", phone: "02838990088",
      address_line: "35 Nguyễn Văn Hưởng", ward: "Thảo Điền", district: "Quận 2", city: "TP.HCM",
      rooms: [["Khu foot B", "foot", 4], ["Phòng 1", "single", 1], ["Phòng 2", "single", 1],
              ["Phòng body", "body", 1], ["Phòng máy", "laser", 1]] }
  ]

  branches = branch_specs.map do |spec|
    b = ws.branches.find_or_create_by!(name: spec[:name]) do |br|
      br.assign_attributes(spec.slice(:code, :phone, :address_line, :ward, :district, :city))
      br.description = "Không gian trị liệu yên tĩnh, trà thảo mộc miễn phí, có chỗ gửi xe."
      br.directions = "Gửi xe trong hầm, đi thang máy lên tầng 3."
    end
    b.ensure_hours!
    spec[:rooms].each_with_index do |(name, type_key, cap), i|
      b.rooms.find_or_create_by!(name: name) do |r|
        r.workspace = ws
        r.room_type = types[type_key]
        r.capacity = cap
        r.code = "#{spec[:code]}#{i + 1}"
        r.position = i
      end
    end
    b
  end
  main = branches.first

  # ---- Nhân sự ----------------------------------------------------------
  staff_specs = [
    { code: "01", name: "Nguyễn Thị Lan",   nickname: "Lan",  gender: "female", role: "therapist", level: "master" },
    { code: "02", name: "Trần Thị Mai",     nickname: "Mai",  gender: "female", role: "therapist", level: "senior" },
    { code: "03", name: "Phạm Thị Hồng",    nickname: "Hồng", gender: "female", role: "therapist", level: "standard" },
    { code: "04", name: "Võ Văn Tuấn",      nickname: "Tuấn", gender: "male",   role: "therapist", level: "senior" },
    { code: "05", name: "Lý Thị Thu",       nickname: "Thu",  gender: "female", role: "therapist", level: "standard" },
    { code: "06", name: "Đặng Thị Kim",     nickname: "Kim",  gender: "female", role: "therapist", level: "standard", branch: 1 },
    { code: "07", name: "Huỳnh Văn Nam",    nickname: "Nam",  gender: "male",   role: "therapist", level: "senior",   branch: 1 },
    { code: nil,  name: "Lê Thu Hà",        nickname: "Hà",   gender: "female", role: "receptionist", level: nil, user: :reception },
    { code: nil,  name: "Ngô Thanh Thảo",   nickname: "Thảo", gender: "female", role: "consultant", level: nil }
  ]

  staff_specs.each do |spec|
    branch = branches[spec[:branch] || 0]
    s = ws.staff_members.find_or_create_by!(name: spec[:name]) do |st|
      st.assign_attributes(
        code: spec[:code], nickname: spec[:nickname], gender: spec[:gender], role: spec[:role],
        branch: branch, staff_level: spec[:level] ? levels[spec[:level]] : nil,
        hired_at: Date.current - rand(60..900).days,
        base_salary: spec[:role] == "therapist" ? 5_000_000 : 8_000_000,
        online_bookable: spec[:role] == "therapist",
        phone: "09#{rand(10_000_000..99_999_999)}",
        bio: spec[:role] == "therapist" ? "Thế mạnh: massage trị liệu vai cổ, bấm huyệt chân." : nil
      )
      st.user = reception if spec[:user] == :reception
    end

    # Mẫu ca: KTV chạy 6 ngày/tuần, nghỉ một ngày xoay vòng.
    next unless s.role == "therapist"
    off_day = (s.code.to_i % 7)
    (0..6).each do |wd|
      next if wd == off_day
      s.shift_templates.find_or_create_by!(weekday: wd) do |t|
        t.workspace = ws
        t.branch = s.branch
        t.starts_at = wd.zero? ? "10:00" : "09:00"
        t.ends_at   = "21:00"
      end
    end
  end

  ws.memberships.find_or_create_by!(user: reception) { |m| m.role = "receptionist"; m.branch = main }

  # Sinh ca thật cho 40 ngày trước (để bill lịch sử có KTV) và 2 tuần tới.
  StaffShift.generate_from_templates!(ws, from: Date.current - 40,
                                          to: Date.current.beginning_of_week + 13)

  # Một KTV xin nghỉ phép để thấy engine cắt đúng khoảng đó.
  lan = ws.staff_members.find_by(code: "01")
  if lan && !ws.staff_shifts.exists?(staff_member_id: lan.id, kind: "leave")
    d = Date.current + 3
    ws.staff_shifts.create!(staff_member: lan, branch: lan.branch, work_date: d, kind: "leave",
                            starts_at: Time.zone.local(d.year, d.month, d.day, 9),
                            ends_at: Time.zone.local(d.year, d.month, d.day, 13),
                            note: "Nghỉ buổi sáng đi khám")
  end

  # ---- Khách hàng -------------------------------------------------------
  customer_specs = [
    { phone: "0905111222", name: "Nguyễn Thị Hoa", gender: "female", tier: "gold",
      visits: 24, spent: 18_600_000, prefs: { "pressure" => "Mạnh", "staff_gender" => "Nữ", "oil" => "Sả chanh" },
      health: "Thoát vị đĩa đệm nhẹ L4-L5, tránh ấn mạnh vùng thắt lưng." },
    { phone: "0908333444", name: "Lê Quốc Dũng", gender: "male", tier: "silver",
      visits: 11, spent: 7_400_000, prefs: { "pressure" => "Rất mạnh", "chat" => "Im lặng nghỉ ngơi" } },
    { phone: "0912555666", name: "Trần Mỹ Linh", gender: "female", tier: "platinum",
      visits: 58, spent: 46_200_000, prefs: { "pressure" => "Nhẹ", "oil" => "Oải hương", "room_temp" => "Ấm" },
      health: "Dị ứng tinh dầu bạc hà." },
    { phone: "0933777888", name: "Phan Thị Ngọc", gender: "female", tier: "member",
      visits: 2, spent: 900_000, prefs: { "staff_gender" => "Nữ" } },
    { phone: "0977222333", name: "Bùi Văn Khang", gender: "male", tier: "member",
      visits: 0, spent: 0, prefs: {} }
  ]

  customer_specs.each_with_index do |spec, i|
    m = Member.find_or_initialize_by(workspace: ws, phone: spec[:phone])
    next unless m.new_record?
    m.assign_attributes(
      name: spec[:name], gender: spec[:gender], member_tier: tiers[spec[:tier]],
      home_branch: branches[i % branches.size],
      dob: Date.new(1985 + (i * 3), ((i * 4) % 12) + 1, ((i * 7) % 27) + 1),
      visits_count: spec[:visits], total_spent: spec[:spent],
      preferences: spec[:prefs], health_notes: spec[:health],
      source: i.zero? ? "walk_in" : %w[self_signup online referral walk_in][i % 4],
      # Khách thật hầu như luôn đổi điểm dần, nên số dư điểm chỉ là một phần nhỏ
      # của tổng tích luỹ. Để nguyên spent/1000 sẽ ra số dư vài chục nghìn điểm
      # — trông như lỗi và khiến màn thu ngân đề nghị trả gần hết bill bằng điểm.
      points_balance: (spec[:spent] / 1000 * ws.setting_i("points_per_1000_spent") * 0.08).round,
      wallet_balance: i == 2 ? 2_000_000 : 0,
      first_visit_at: spec[:visits].positive? ? rand(60..500).days.ago : nil,
      last_visit_at: spec[:visits].positive? ? rand(1..40).days.ago : nil,
      preferred_staff: spec[:visits] > 5 ? ws.staff_members.therapists.order(:code).first : nil
    )
    m.save!
  end


  # ---- Danh mục dịch vụ ---------------------------------------------------
  ServiceCategory.presets_for(ws.business_type).each_with_index do |attrs, i|
    ws.service_categories.find_or_create_by!(name: attrs[:name]) { |c| c.assign_attributes(attrs.merge(position: i)) }
  end
  cats = ws.service_categories.index_by(&:name)

  service_specs = [
    # [tên, nhóm, phút, giá, loại phòng, biến thể]
    ["Massage body tinh dầu", "Massage body", 60, 450_000, %w[single couple vip],
     [["90′", 90, 620_000], ["120′", 120, 820_000]]],
    ["Massage đá nóng",       "Massage body", 90, 750_000, %w[single vip], []],
    ["Massage trị liệu vai cổ", "Trị liệu",   60, 520_000, %w[single], [["90′", 90, 720_000]]],
    ["Foot massage",          "Foot massage", 45, 250_000, %w[foot],
     [["60′", 60, 320_000], ["90′", 90, 450_000]]],
    ["Ngâm chân thảo dược",   "Foot massage", 30, 150_000, %w[foot], []],
    ["Chăm sóc da cơ bản",    "Chăm sóc da",  60, 400_000, %w[facial], []],
    ["Trị mụn chuyên sâu",    "Trị liệu da",  75, 850_000, %w[facial laser], []],
    ["Xông hơi & jacuzzi",    "Xông hơi & jacuzzi", 45, 120_000, %w[sauna], []]
  ]

  service_specs.each_with_index do |(name, cat, mins, price, type_keys, variants), i|
    svc = ws.services.find_or_initialize_by(name: name)
    if svc.new_record?
      svc.assign_attributes(
        service_category: cats[cat], duration_minutes: mins, price: price,
        cost: (price * 0.12).round(-3), position: i,
        room_type_ids: type_keys.filter_map { |k| types[k]&.id },
        requires_staff: name.include?("Xông hơi") ? false : true,
        staff_count: name.include?("Xông hơi") ? 0 : 1,
        description: "Liệu trình #{mins} phút trong không gian yên tĩnh, kết thúc bằng trà thảo mộc."
      )
      svc.save!
      # Khi dịch vụ có biến thể thì CHỈ biến thể được bán, nên mốc gốc cũng phải
      # là một biến thể — nếu không, 60′ biến mất khỏi menu của khách.
      variants.each_with_index do |(vname, vmins, vprice), vi|
        svc.service_variants.create!(workspace: ws, name: vname, duration_minutes: vmins,
                                     price: vprice, position: vi + 1)
      end
    end
    # Chạy mọi lần seed (kể cả dịch vụ đã có): dịch vụ có biến thể thì mốc gốc
    # cũng phải là một biến thể, nếu không 60′ biến mất khỏi menu của khách.
    if svc.service_variants.any? && svc.service_variants.none? { |v| v.duration_minutes == mins }
      svc.service_variants.create!(workspace: ws, name: "#{mins}′", duration_minutes: mins,
                                   price: price, position: 0)
    end
  end

  # Addon
  [["Ngải cứu nóng", 15, 80_000], ["Giác hơi", 20, 150_000], ["Đắp mặt nạ", 15, 120_000]].each do |nm, mins, price|
    ws.services.find_or_create_by!(name: nm) do |a|
      a.is_addon = true
      a.duration_minutes = mins
      a.price = price
      a.requires_room = false
      a.requires_staff = false
      a.staff_count = 0
    end
  end

  # ---- Thêm khách để số lượt đến hợp lý ----------------------------------
  # 748 lịch hẹn chia cho 5 khách ra "123 lượt đến" cho một hồ sơ tạo hôm nay —
  # con số tự tố là dữ liệu giả. Với ~45 khách thì mỗi người 10–25 lượt, đúng
  # như tệp khách của một spa chạy vài năm.
  if ws.members.count < 40
    tiers_by_key = ws.member_tiers.index_by(&:key)
    40.times do |i|
      phone = format("09%08d", 20_000_000 + i * 137)
      next if ws.members.exists?(phone: phone)
      female = i.even?
      ws.members.create!(
        phone: phone,
        name: Faker::Name.public_send(female ? "female_first_name" : "male_first_name")
                        .then { |first| "#{Faker::Name.last_name} #{first}" },
        gender: female ? "female" : "male",
        member_tier: tiers_by_key.values.sample,
        home_branch: branches[i % branches.size],
        dob: Date.new(1980 + (i % 25), (i % 12) + 1, (i % 27) + 1),
        source: %w[walk_in self_signup online referral][i % 4],
        marketing_opt_in: (i % 7) != 0,
        preferences: i.even? ? { "pressure" => ["Nhẹ", "Trung bình", "Mạnh"].sample } : {},
        last_seen_at: (i % 3).zero? ? rand(1..40).days.ago : nil
      ).tap do |m|
        # Rải ngày tạo hồ sơ: để nguyên hôm nay thì chỉ số "hồ sơ mới trong
        # kỳ" luôn bằng toàn bộ tệp khách. Spa thật nào cũng có khách mới mỗi
        # tháng, nên 1/5 tệp khách nằm trong 30 ngày gần nhất, còn lại rải 2 năm.
        age = (i % 5).zero? ? rand(1..29) : rand(30..730)
        m.update_columns(created_at: age.days.ago)
      end
    end
  end


  # ---- Gói / thẻ liệu trình ----------------------------------------------
  body   = ws.services.find_by(name: "Massage body tinh dầu")
  foot   = ws.services.find_by(name: "Foot massage")
  facial = ws.services.find_by(name: "Chăm sóc da cơ bản")

  pkg_specs = [
    { name: "Thẻ 10 buổi massage body", kind: "session_pack", price: 3_900_000,
      validity_days: 180, lines: [[body, 10]] },
    { name: "Thẻ 10 buổi foot massage", kind: "session_pack", price: 2_200_000,
      validity_days: 180, lines: [[foot, 10]] },
    { name: "Combo 5 body + 5 foot", kind: "session_pack", price: 2_900_000,
      validity_days: 120, lines: [[body, 5], [foot, 5]] },
    { name: "Liệu trình da 8 buổi", kind: "session_pack", price: 2_800_000,
      validity_days: 150, lines: [[facial, 8]] },
    { name: "Thẻ tiền 5 triệu", kind: "value_card", price: 5_000_000,
      face_value: 6_000_000, validity_days: 365, lines: [] }
  ]

  pkg_specs.each_with_index do |spec, i|
    next if spec[:lines].any? { |(svc, _)| svc.nil? }
    pkg = ws.packages.find_or_initialize_by(name: spec[:name])
    next unless pkg.new_record?
    pkg.assign_attributes(kind: spec[:kind], price: spec[:price], face_value: spec[:face_value],
                          validity_days: spec[:validity_days], position: i, active: true,
                          description: "Mua gói tiết kiệm hơn đi lẻ, dùng trong #{spec[:validity_days]} ngày.")
    pkg.save!
    spec[:lines].each { |(svc, n)| pkg.package_lines.create!(workspace: ws, service: svc, sessions: n) }
  end

  # Bán sẵn một thẻ cho khách quen để thấy luồng trừ buổi.
  vip = Member.find_by(workspace: ws, phone: "0912555666")
  combo = ws.packages.find_by(name: "Thẻ 10 buổi massage body")
  if vip && combo && vip.member_packages.empty?
    card = vip.member_packages.create!(
      workspace: ws, package: combo, name: combo.name, kind: combo.kind,
      price_paid: combo.price, purchased_on: Date.current - 40,
      expires_on: Date.current + 140,
      sold_by: ws.staff_members.find_by(role: "consultant")
    )
    combo.package_lines.each do |line|
      card.package_credits.create!(workspace: ws, service: line.service,
                                   total_sessions: line.sessions, used_sessions: 3)
    end
  end

  # ---- Lịch hẹn mẫu cho hôm nay & mai -------------------------------------
  if ws.bookings.count.zero?
    bookable = ws.services.main.active.where(requires_staff: true).to_a
    guests = ws.members.to_a
    # Hôm nay và mai phải dày như các ngày khác: trang Tổng quan là thứ người
    # xem mở đầu tiên, để nó trống thì cả sản phẩm trông như chưa ai dùng.
    [Date.current, Date.current + 1].each do |day|
      slots = (9..20).flat_map { |h| [[h, 0], [h, 30]] }.shuffle.first(rand(22..30))
      slots.each_with_index do |(hour, minute), idx|
        svc = bookable[idx % bookable.size]
        member = guests[idx % guests.size]
        at = Time.zone.local(day.year, day.month, day.day, hour, minute)
        res = BookingScheduler.create(
          branch: branches[idx % branches.size], starts_at: at,
          lines: [{ service: svc }], member: member,
          source: %w[staff app phone walk_in][idx % 4], status: "confirmed"
        )
        next unless res.ok?
        b = res.booking
        # Lịch của hôm qua/hôm nay đã qua giờ thì cho chạy tiếp trạng thái để
        # màn hình hàng chờ có cả ba cột dữ liệu.
        next unless day == Date.current
        if at < Time.current - 2.hours
          # Buổi đã xong thì phải có BILL, nếu không "đã thu hôm nay" ra 0đ trong
          # khi hôm nay có 20 lịch hẹn — hai con số cạnh nhau tự tố nhau.
          b.transition_to!("checked_in")
          b.transition_to!("in_progress")
          o = Checkout.open_for_booking(booking: b, actor: owner).order
          if o
            Checkout.add_tip(order: o, amount: [50_000, 100_000].sample, staff: b.booking_items.first&.staff_member) if rand < 0.35
            o.reload
            Checkout.pay(order: o, method: %w[cash vietqr transfer card].sample, amount: o.total, actor: owner)
            Checkout.close!(order: o, actor: owner)
          end
        elsif at < Time.current
          b.transition_to!("checked_in")
        end
      end
    end
  end

  # ---- Bill đã đóng của 35 ngày trước → báo cáo & hoa hồng có dữ liệu thật ---
  # Điều kiện phải độc lập với khối "hôm nay & mai" ở trên: khối đó cũng tạo
  # bill, nên `ws.orders.count.zero?` sẽ luôn FALSE và toàn bộ dữ liệu lịch sử
  # không bao giờ được sinh (đã vấp: seed chỉ ra 38 lịch hẹn thay vì ~750).
  if ws.orders.where("closed_at < ?", Date.current.beginning_of_day).count.zero?
    cashier = owner
    ws.members.reload
    sellable = ws.services.main.active.where(requires_staff: true).to_a
    therapists = ws.staff_members.active.therapists.to_a
    customers = ws.members.to_a
    # Phủ TRỌN 35 ngày: mọi khoảng xem (7/30/90 ngày) phải có dữ liệu suốt kỳ,
    # nếu không doanh thu của 21 ngày bị đem so với chi phí của cả tháng và lãi
    # thô ra số âm vô lý.
    #
    # 32–44 lượt/ngày trên 7 KTV × ~11 giờ ca → tỷ lệ dùng KTV ~45–55%, đúng
    # vùng trung bình ngành (50–60%). Ít hơn nữa thì mọi chỉ số hiệu suất trong
    # demo đều gần 0 và người xem tưởng hệ thống tính sai.
    (1..35).each do |days_ago|
      day = Date.current - days_ago
      rand(32..44).times do |n|
        svc = sellable.sample
        st  = therapists.sample
        cust = rand < 0.8 ? customers.sample : nil
        at = Time.zone.local(day.year, day.month, day.day, rand(9..19), [0, 30].sample)
        res = BookingScheduler.create(
          branch: branches[n % branches.size], starts_at: at, member: cust,
          guest_name: cust ? nil : "Khách lẻ",
          lines: [{ service: svc, staff: st }], source: %w[staff app phone walk_in].sample,
          status: "confirmed"
        )
        next unless res.ok?
        b = res.booking
        b.transition_to!("checked_in")
        b.transition_to!("in_progress")
        order = Checkout.open_for_booking(booking: b, actor: cashier).order
        next if order.nil?
        Checkout.add_tip(order: order, amount: [0, 0, 50_000, 100_000].sample, staff: st) if rand < 0.4
        order.reload
        Checkout.pay(order: order, method: %w[cash vietqr transfer card].sample,
                     amount: order.total, actor: cashier)
        Checkout.close!(order: order, actor: cashier)
        # Ngày bán được thẻ
        if rand < 0.12 && cust
          pkg = ws.packages.active.sample
          blank = Checkout.open_blank(branch: b.branch, member: cust, actor: cashier).order
          Checkout.add_package(order: blank, package: pkg,
                               consultant: ws.staff_members.find_by(role: "consultant"))
          blank.reload
          Checkout.pay(order: blank, method: "transfer", amount: blank.total, actor: cashier)
          Checkout.close!(order: blank, actor: cashier)
          # Bill bán thẻ không gắn lịch hẹn nên vòng lùi ngày phía dưới bỏ qua nó
          # → tất cả dồn về HÔM NAY và ngày hôm nay hiện 72 bill trong khi chỉ có
          # 22 lịch hẹn. Lùi ngay tại đây.
          blank.update_columns(closed_at: at + 90.minutes, created_at: at)
          blank.commission_entries.update_all(earned_on: day)
        end
      end
    end
    # `last_visit_at` được đặt = Time.current mỗi lần hoàn tất buổi, nên sau khi
    # seed cả 45 khách đều "lần cuối chưa đến 1 phút trước". Lùi về ngày buổi
    # cuối thật của từng người.
    ws.members.each do |m|
      last = m.bookings.where(status: "completed").maximum(:starts_at)
      first = m.bookings.where(status: "completed").minimum(:starts_at)
      m.update_columns(last_visit_at: last, first_visit_at: first) if last
    end

    # Lùi ngày đóng bill về đúng ngày phát sinh để báo cáo theo kỳ đúng.
    ws.orders.paid.each do |o|
      next if o.booking.nil? # bill bán thẻ đã được lùi ngay lúc tạo
      o.update_columns(closed_at: o.booking.starts_at + 1.hour, created_at: o.booking.starts_at)
      o.commission_entries.update_all(earned_on: o.booking.starts_at.to_date)
      # Sổ điểm và biến động ví của khách hiển thị theo `created_at`; không lùi
      # thì "Biến động điểm" trong app khách ra cả trang cùng một phút hôm nay.
      at = o.booking.starts_at + 1.hour
      PointTransaction.where(order_id: o.id).update_all(created_at: at, updated_at: at)
      WalletTransaction.where(order_id: o.id).update_all(created_at: at, updated_at: at)
    end
  end

  # ---- Chi phí vận hành ---------------------------------------------------
  # Ghi theo TUẦN thay vì theo tháng: chi phí một tháng nén vào 17 ngày đã qua
  # khiến mọi cửa sổ 30 ngày hứng hơn một tháng chi phí đọ với một tháng doanh
  # thu, và lãi thô ra số âm vô lý. Ghi theo tuần thì khoảng nào cũng tỷ lệ đúng.
  if ws.expenses.count.zero?
    # Cơ cấu chi phí THEO THÁNG của một spa hai cơ sở doanh thu ~500tr/tháng
    # (mặt bằng + lương chiếm phần lớn, tổng ~65% doanh thu → lãi thô 15–25%).
    monthly = [
      ["rent",      "Thuê mặt bằng",          48_000_000],
      ["payroll",   "Lương cứng nhân sự",     96_000_000],
      ["supplies",  "Tinh dầu, khăn, mặt nạ", 24_000_000],
      ["utility",   "Điện nước internet",     10_000_000],
      ["marketing", "Quảng cáo Facebook",     14_000_000],
      ["equipment", "Bảo trì giường & máy",    5_000_000]
    ]
    weeks = ((Date.current - 120)..Date.current).step(7).to_a
    weeks.each do |week_start|
      branches.each_with_index do |br, bi|
        scale = bi.zero? ? 1.0 : 0.62 # cơ sở thứ hai nhỏ hơn
        monthly.each do |cat, note, month_amount|
          amount = ((month_amount * scale) / 4.345).round(-4) # một tuần
          next if amount.zero?
          ws.expenses.create!(branch: br, category: cat, note: note, amount: amount,
                              spent_on: [week_start + rand(0..6), Date.current].min)
        end
      end
    end
  end

  # Một khách bỏ hẹn nhiều lần → thấy được cơ chế chặn đặt online.
  noshow = Member.find_by(workspace: ws, phone: "0977222333")
  noshow&.update!(no_show_count: 3, cancel_count: 1)
end

puts "  ✓ Spa demo: #{ws.name} (#{ws.subdomain}) — #{ws.branches.count} cơ sở, " \
     "#{ws.rooms.count} phòng (#{ws.rooms.sum(:capacity)} chỗ), " \
     "#{ws.staff_members.count} nhân sự, #{ws.staff_shifts.count} ca, #{ws.members.count} khách"
puts "  ✓ Danh mục: #{ws.services.main.count} dịch vụ (#{ws.service_variants.count} biến thể), " \
     "#{ws.services.where(is_addon: true).count} addon, #{ws.packages.count} gói/thẻ"
puts "  ✓ Vận hành mẫu: #{ws.bookings.count} lịch hẹn, #{ws.orders.paid.count} bill đã đóng " \
     "(#{ActiveSupport::NumberHelper.number_to_delimited(ws.orders.paid.sum(:total))}đ), " \
     "#{ws.commission_entries.count} dòng hoa hồng"
puts "  ✓ Chủ spa: chu@aura.local#{seed_password_hint(owner_created)}"
puts "  ✓ Lễ tân:  letan@aura.local#{seed_password_hint(reception_created)}"
puts "  ✓ Khách demo (đăng nhập bằng SĐT + OTP): 0905111222"
puts "Done."
