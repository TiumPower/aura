module Admin
  # Công tắc cấp nền tảng mà super admin bật/tắt ngay lúc chạy — không cần deploy
  # hay sửa .env. Hiện tại: có hiện mã OTP thẳng trên màn hình hay không.
  class SettingsController < BaseController
    def show
      @customer = AppSetting.show_otp_customer?
      @staff    = AppSetting.show_otp_staff?
      @gateway  = OtpGateway.status
    end

    def update
      key = params[:scope] == "staff" ? AppSetting::SHOW_OTP_STAFF_KEY : AppSetting::SHOW_OTP_CUSTOMER_KEY
      AppSetting.set_flag(key, params[:on])
      redirect_to admin_settings_path, notice: "Đã cập nhật công tắc hiện OTP."
    end

    # ---- Cổng gửi OTP qua Zalo ----------------------------------------------
    # Refresh token của Zalo OA đổi sau mỗi lần dùng, nên giá trị trong .env sẽ
    # cũ đi; phải dán được token mới mà không cần deploy lại.
    def update_gateway
      if OtpGateway.store_refresh_token(params[:zns_refresh_token])
        redirect_to admin_settings_path, notice: "Đã lưu refresh token Zalo OA mới."
      else
        redirect_to admin_settings_path, alert: "Chưa nhập refresh token."
      end
    end

    # Gửi một tin thật tới một số thật. Mọi thứ khác của cổng này có thể trông
    # đúng mà vẫn không gửi được (template chưa được duyệt, sai OA id, token hết
    # hạn), nên phải có đường thử thật.
    def test_otp
      result = OtpGateway.test_send(params[:phone])
      if result.ok?
        redirect_to admin_settings_path,
                    notice: "Đã gửi thử qua #{result.provider}. Kiểm tra Zalo trên số đó."
      else
        redirect_to admin_settings_path,
                    alert: "Gửi thử thất bại (#{result.provider || "chưa cấu hình"}): #{result.error}"
      end
    end

    private

    def nav_key = :settings
  end
end
