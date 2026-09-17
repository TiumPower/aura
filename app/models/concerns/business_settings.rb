# Mọi quy tắc nghiệp vụ có thể khác nhau giữa các spa nằm ở đây dưới dạng tham
# số, đọc/ghi vào `workspaces.settings["business"]` (jsonb). Không hard-code:
# một tiệm foot massage nhận khách walk-in liên tục và một TMV chỉ nhận hẹn
# trước 1 ngày dùng CÙNG một bộ mã, khác nhau ở đây.
#
# `Branch#setting` đọc tiếp lớp ghi đè của từng chi nhánh (xem BranchSettings).
module BusinessSettings
  extend ActiveSupport::Concern

  # Các module bật/tắt theo nhu cầu từng spa. Mặc định suy ra từ business_type.
  MODULES = %w[
    booking pos packages wallet loyalty commissions inventory
    treatment_records consent reviews chat walk_in
  ].freeze

  # Module CHƯA có màn hình nào. Chúng vẫn nằm trong danh sách để lộ rõ lộ trình,
  # nhưng KHÔNG được bật: bật lên mà không có gì xảy ra là hứa suông với người
  # đang trả tiền. `enabled_modules` lọc chúng ra nên không phần nào của app tin
  # rằng chúng đang chạy.
  COMING_SOON_MODULES = %w[inventory treatment_records consent reviews].freeze

  MODULE_LABELS = {
    "booking" => "Đặt lịch", "pos" => "Thu ngân / bán hàng",
    "packages" => "Thẻ liệu trình & gói", "wallet" => "Ví / thẻ tiền",
    "loyalty" => "Điểm thưởng & hạng thẻ", "commissions" => "Hoa hồng & lương",
    "inventory" => "Kho & vật tư", "treatment_records" => "Hồ sơ điều trị",
    "consent" => "Phiếu đồng ý & tư vấn", "reviews" => "Đánh giá sau buổi",
    "chat" => "Chat với khách", "walk_in" => "Khách vãng lai (walk-in)"
  }.freeze

  # Bộ module gợi ý theo loại hình. Tiệm massage cần sơ đồ phòng và walk-in;
  # TMV cần liệu trình, hồ sơ điều trị và phiếu đồng ý.
  MODULE_PRESETS = {
    "massage" => %w[booking pos packages wallet loyalty commissions walk_in reviews chat],
    "beauty"  => %w[booking pos packages loyalty commissions inventory treatment_records consent reviews chat],
    "mixed"   => MODULES
  }.freeze

  DEFAULTS = {
    # ---- Lịch & đặt hẹn ------------------------------------------------
    "slot_step_minutes"      => 15,   # lưới giờ khách chọn
    "booking_lead_minutes"   => 60,   # phải đặt trước ít nhất bao lâu
    "booking_horizon_days"   => 30,   # đặt trước tối đa bao nhiêu ngày
    "cancel_cutoff_hours"    => 4,    # sát giờ hơn mức này thì khách không tự huỷ
    "reschedule_cutoff_hours" => 4,
    "auto_confirm_online"    => true, # false = lễ tân duyệt từng lịch
    "allow_staff_choice"     => true, # khách được chỉ định KTV
    "allow_room_choice"      => false,
    "allow_gender_preference" => true, # khách chọn KTV nam/nữ
    "default_turnaround_minutes" => 10, # dọn phòng giữa hai lượt
    "checkin_early_minutes"  => 20,    # cho check-in sớm bao nhiêu phút
    "late_grace_minutes"     => 15,    # quá bao lâu thì coi là khách trễ
    "auto_no_show_minutes"   => 30,    # quá bao lâu thì tự đánh no-show
    "max_party_size"         => 6,     # một lịch hẹn tối đa mấy khách
    "overbook_allowed"       => false,
    "reminder_hours"         => [24, 3],

    # ---- Đặt cọc & no-show ---------------------------------------------
    "require_deposit"        => false,
    "deposit_percent"        => 0,
    "deposit_min_amount"     => 0,
    "no_show_fee"            => 0,
    "block_after_no_shows"   => 3,     # nhiều hơn mức này thì chặn đặt online

    # ---- Tiền & thuế ----------------------------------------------------
    "currency"               => "VND",
    "vat_percent"            => 0,
    "price_includes_vat"     => true,
    "service_charge_percent" => 0,
    "rounding"               => 1_000,  # làm tròn tổng bill
    "tip_enabled"            => true,
    "tip_to_staff_percent"   => 100,    # tip về tay KTV bao nhiêu %

    # ---- Thẻ liệu trình / gói -------------------------------------------
    "package_validity_days"  => 180,
    "package_transferable"   => false,
    "package_family_share"   => false,
    "low_sessions_threshold" => 2,      # còn ≤ n buổi thì nhắc gia hạn
    "package_expiry_warning_days" => 15,

    # ---- Ví / thẻ tiền ---------------------------------------------------
    "wallet_topup_bonus_percent" => 0,
    "wallet_min_topup"       => 500_000,

    # ---- Điểm thưởng -----------------------------------------------------
    "points_per_1000_spent"  => 1,
    "points_value"           => 100,    # 1 điểm đổi được bao nhiêu đồng
    "points_expiry_months"   => 12,
    "points_redeem_min"      => 50,

    # ---- Hoa hồng & lương ------------------------------------------------
    "commission_default_percent"   => 15,  # KTV làm dịch vụ
    "consultant_commission_percent" => 5,  # người tư vấn chốt thẻ
    "commission_on_package_sale_percent" => 5,
    "commission_basis"       => "net",     # net (sau giảm giá) | gross
    "payroll_cycle"          => "monthly", # monthly | biweekly
    "payroll_close_day"      => 5,

    # ---- Hồ sơ & vận hành -------------------------------------------------
    "treatment_record_required" => false, # KTV phải ghi hồ sơ mới đóng bill
    "consent_required"       => false,
    "health_form_required"   => false,
    "staff_can_see_customer_phone" => false,

    # ---- Đánh giá ---------------------------------------------------------
    "review_request_hours"   => 2,     # gửi lời mời đánh giá sau bao lâu
    "review_min_publish"     => 4      # từ mấy sao mới hiện công khai
  }.freeze

  # Đọc một tham số (rơi về default nếu chưa đặt).
  def setting(key)
    key = key.to_s
    stored = settings.is_a?(Hash) ? settings.dig("business", key) : nil
    stored.nil? ? DEFAULTS[key] : stored
  end

  def setting?(key) = ActiveModel::Type::Boolean.new.cast(setting(key)).present?
  def setting_i(key) = setting(key).to_i

  # Ghi một loạt tham số. Giá trị rỗng = xoá để quay về default.
  def update_business_settings!(attrs)
    biz = (settings["business"] || {}).dup
    attrs.each do |k, v|
      k = k.to_s
      next unless DEFAULTS.key?(k)
      if v.nil? || v == ""
        biz.delete(k)
      else
        biz[k] = cast_setting(k, v)
      end
    end
    update!(settings: settings.merge("business" => biz))
  end

  def cast_setting(key, value)
    default = DEFAULTS[key]
    case default
    when true, false then ActiveModel::Type::Boolean.new.cast(value)
    when Integer     then value.to_s.gsub(/[^\d-]/, "").to_i
    when Array       then value.is_a?(Array) ? value : value.to_s.split(",").map { |s| s.strip.to_i }
    else value
    end
  end

  # ---- Module bật/tắt ---------------------------------------------------
  def enabled_modules
    stored = settings["modules"]
    keys = stored.is_a?(Array) ? Array(stored) & MODULES :
             (MODULE_PRESETS[business_type] || MODULE_PRESETS["mixed"])
    keys - COMING_SOON_MODULES
  end

  def module_coming_soon?(key) = COMING_SOON_MODULES.include?(key.to_s)

  def module?(key) = enabled_modules.include?(key.to_s)

  def update_modules!(keys)
    allowed = MODULES - COMING_SOON_MODULES
    update!(settings: settings.merge("modules" => Array(keys).map(&:to_s) & allowed))
  end
end
