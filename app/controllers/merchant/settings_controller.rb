module Merchant
  # Bộ tham số nghiệp vụ + bộ module của spa. Đây là nơi hai spa dùng cùng một
  # bộ mã nhưng chạy hai cách vận hành khác nhau.
  class SettingsController < BaseController
    before_action :require_manager!

    # Nhóm tham số để trang thiết lập đọc được, thay vì một danh sách 50 dòng.
    GROUPS = [
      { key: "booking", title: "Lịch & đặt hẹn", icon: "📅",
        keys: %w[slot_step_minutes booking_lead_minutes booking_horizon_days
                 cancel_cutoff_hours reschedule_cutoff_hours auto_confirm_online
                 allow_staff_choice allow_room_choice allow_gender_preference
                 default_turnaround_minutes checkin_early_minutes late_grace_minutes
                 auto_no_show_minutes max_party_size overbook_allowed] },
      { key: "deposit", title: "Đặt cọc & khách bỏ hẹn", icon: "🔒",
        keys: %w[require_deposit deposit_percent deposit_min_amount no_show_fee block_after_no_shows] },
      { key: "money", title: "Tiền, thuế & tip", icon: "💰",
        keys: %w[vat_percent price_includes_vat service_charge_percent rounding
                 tip_enabled tip_to_staff_percent] },
      { key: "packages", title: "Thẻ liệu trình & ví", icon: "🎟️",
        keys: %w[package_validity_days package_transferable package_family_share
                 low_sessions_threshold package_expiry_warning_days
                 wallet_topup_bonus_percent wallet_min_topup] },
      { key: "loyalty", title: "Điểm thưởng", icon: "⭐",
        keys: %w[points_per_1000_spent points_value points_expiry_months points_redeem_min] },
      { key: "payroll", title: "Hoa hồng & lương", icon: "🧮",
        keys: %w[commission_default_percent consultant_commission_percent
                 commission_on_package_sale_percent commission_basis payroll_cycle payroll_close_day] },
      { key: "records", title: "Hồ sơ & quyền xem", icon: "📋",
        keys: %w[treatment_record_required consent_required health_form_required
                 staff_can_see_customer_phone] },
      { key: "reviews", title: "Đánh giá sau buổi", icon: "💬",
        keys: %w[review_request_hours review_min_publish] }
    ].freeze

    LABELS = {
      "slot_step_minutes" => ["Bước giờ khách chọn (phút)", "Lưới giờ hiện cho khách: 15 phút là phổ biến nhất."],
      "booking_lead_minutes" => ["Đặt trước tối thiểu (phút)", "Sát giờ hơn mức này thì khách phải gọi điện."],
      "booking_horizon_days" => ["Đặt trước tối đa (ngày)", nil],
      "cancel_cutoff_hours" => ["Khách tự huỷ trước (giờ)", "Sát hơn thì phải gọi lễ tân — tránh phòng trống phút cuối."],
      "reschedule_cutoff_hours" => ["Khách tự đổi giờ trước (giờ)", nil],
      "auto_confirm_online" => ["Tự xác nhận lịch đặt online", "Tắt = lễ tân duyệt từng lịch trước khi thành hẹn chắc."],
      "allow_staff_choice" => ["Cho khách chọn KTV", nil],
      "allow_room_choice" => ["Cho khách chọn phòng", "Ít spa bật cái này — dễ tạo khoảng trống lịch không lấp được."],
      "allow_gender_preference" => ["Cho khách chọn KTV nam/nữ", nil],
      "default_turnaround_minutes" => ["Thời gian dọn phòng (phút)", "Chèn giữa hai lượt khách của cùng một phòng."],
      "checkin_early_minutes" => ["Cho check-in sớm (phút)", nil],
      "late_grace_minutes" => ["Ngưỡng coi là khách trễ (phút)", nil],
      "auto_no_show_minutes" => ["Tự đánh no-show sau (phút)", "0 = không tự đánh, lễ tân tự xử lý."],
      "max_party_size" => ["Số khách tối đa một lịch hẹn", nil],
      "overbook_allowed" => ["Cho phép xếp vượt sức chứa", "Bật khi tiệm hay nhận thêm khách quen — engine sẽ không chặn."],
      "require_deposit" => ["Yêu cầu đặt cọc khi đặt online", "Cần nối cổng thanh toán trước khi bật."],
      "deposit_percent" => ["Cọc theo % giá dịch vụ", nil],
      "deposit_min_amount" => ["Cọc tối thiểu (đ)", nil],
      "no_show_fee" => ["Phí bỏ hẹn (đ)", nil],
      "block_after_no_shows" => ["Chặn đặt online sau n lần bỏ hẹn", "0 = không chặn."],
      "vat_percent" => ["VAT (%)", nil],
      "price_includes_vat" => ["Giá niêm yết đã gồm VAT", nil],
      "service_charge_percent" => ["Phí phục vụ (%)", nil],
      "rounding" => ["Làm tròn tổng bill (đ)", "1.000 = làm tròn tới nghìn."],
      "tip_enabled" => ["Ghi nhận tip cho KTV", nil],
      "tip_to_staff_percent" => ["Tip về tay KTV (%)", "Phần còn lại vào quỹ chung của tiệm."],
      "package_validity_days" => ["Hạn dùng thẻ liệu trình (ngày)", nil],
      "package_transferable" => ["Cho chuyển nhượng thẻ", nil],
      "package_family_share" => ["Cho người thân dùng chung thẻ", nil],
      "low_sessions_threshold" => ["Nhắc gia hạn khi còn ≤ n buổi", nil],
      "package_expiry_warning_days" => ["Nhắc trước khi thẻ hết hạn (ngày)", nil],
      "wallet_topup_bonus_percent" => ["Thưởng khi nạp ví (%)", nil],
      "wallet_min_topup" => ["Nạp ví tối thiểu (đ)", nil],
      "points_per_1000_spent" => ["Điểm nhận trên mỗi 1.000đ", nil],
      "points_value" => ["1 điểm đổi được (đ)", nil],
      "points_expiry_months" => ["Điểm hết hạn sau (tháng)", "0 = không hết hạn."],
      "points_redeem_min" => ["Điểm tối thiểu để đổi", nil],
      "commission_default_percent" => ["Hoa hồng KTV mặc định (%)", "Hạng KTV hoặc từng người có thể ghi đè."],
      "consultant_commission_percent" => ["Hoa hồng tư vấn (%)", nil],
      "commission_on_package_sale_percent" => ["Hoa hồng bán thẻ liệu trình (%)", nil],
      "commission_basis" => ["Tính hoa hồng trên", "net = sau giảm giá, gross = giá niêm yết."],
      "payroll_cycle" => ["Kỳ lương", nil],
      "payroll_close_day" => ["Ngày chốt lương", nil],
      "treatment_record_required" => ["Bắt buộc ghi hồ sơ điều trị", "KTV chưa ghi thì chưa đóng được bill."],
      "consent_required" => ["Bắt buộc phiếu đồng ý", nil],
      "health_form_required" => ["Bắt buộc phiếu khai sức khoẻ", nil],
      "staff_can_see_customer_phone" => ["KTV xem được SĐT khách", "Tắt = chỉ hiện số đã che."],
      "review_request_hours" => ["Gửi lời mời đánh giá sau (giờ)", nil],
      "review_min_publish" => ["Số sao tối thiểu để hiện công khai", nil]
    }.freeze

    CHOICES = {
      "commission_basis" => [["Sau giảm giá (net)", "net"], ["Giá niêm yết (gross)", "gross"]],
      "payroll_cycle"    => [["Theo tháng", "monthly"], ["Hai tuần một lần", "biweekly"]]
    }.freeze

    def show
      @groups = GROUPS
      @labels = LABELS
      @choices = CHOICES
      @defaults = BusinessSettings::DEFAULTS
      @branch = current_workspace.branches.find_by(id: params[:branch_id])
      @branches = current_workspace.branches.ordered.to_a
    end

    def update
      attrs = params.fetch(:business, {}).to_unsafe_h
      # Ô checkbox không được tick thì không gửi lên — bù lại từ danh sách khai
      # tường minh, nếu không thì tắt một công tắc sẽ không bao giờ lưu được.
      Array(params[:booleans]).each { |k| attrs[k] ||= "0" }
      branch = current_workspace.branches.find_by(id: params[:branch_id])
      if branch
        branch.update_branch_settings!(attrs)
        audit!("settings.branch", target: branch, payload: attrs)
        redirect_to merchant_settings_path(branch_id: branch.id), notice: "Đã lưu tham số riêng của #{branch.name}."
      else
        current_workspace.update_business_settings!(attrs)
        audit!("settings.workspace", payload: attrs)
        redirect_to merchant_settings_path, notice: "Đã lưu tham số nghiệp vụ."
      end
    end

    def modules
      @modules = BusinessSettings::MODULES
      @labels  = BusinessSettings::MODULE_LABELS
      @enabled = current_workspace.enabled_modules
    end

    def update_modules
      keys = Array(params[:modules])
      current_workspace.update_modules!(keys)
      audit!("settings.modules", payload: { modules: keys })
      redirect_to merchant_settings_modules_path, notice: "Đã cập nhật các module đang dùng."
    end

    private

    def nav_key = :settings
  end
end
