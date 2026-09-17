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

  # Sinh ca thật cho tuần này và tuần sau.
  StaffShift.generate_from_templates!(ws, from: Date.current.beginning_of_week,
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
      points_balance: (spec[:spent] / 1000 * ws.setting_i("points_per_1000_spent")),
      wallet_balance: i == 2 ? 2_000_000 : 0,
      first_visit_at: spec[:visits].positive? ? rand(60..500).days.ago : nil,
      last_visit_at: spec[:visits].positive? ? rand(1..40).days.ago : nil,
      preferred_staff: spec[:visits] > 5 ? ws.staff_members.therapists.order(:code).first : nil
    )
    m.save!
  end

  # Một khách bỏ hẹn nhiều lần → thấy được cơ chế chặn đặt online.
  noshow = Member.find_by(workspace: ws, phone: "0977222333")
  noshow&.update!(no_show_count: 3, cancel_count: 1)
end

puts "  ✓ Spa demo: #{ws.name} (#{ws.subdomain}) — #{ws.branches.count} cơ sở, " \
     "#{ws.rooms.count} phòng (#{ws.rooms.sum(:capacity)} chỗ), " \
     "#{ws.staff_members.count} nhân sự, #{ws.staff_shifts.count} ca, #{ws.members.count} khách"
puts "  ✓ Chủ spa: chu@aura.local#{seed_password_hint(owner_created)}"
puts "  ✓ Lễ tân:  letan@aura.local#{seed_password_hint(reception_created)}"
puts "  ✓ Khách demo (đăng nhập bằng SĐT + OTP): 0905111222"
puts "Done."
