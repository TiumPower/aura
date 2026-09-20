module Admin
  # Công tắc cấp nền tảng mà super admin bật/tắt ngay lúc chạy — không cần deploy
  # hay sửa .env. Hiện tại: có hiện mã OTP thẳng trên màn hình hay không.
  class SettingsController < BaseController
    def show
      @customer = AppSetting.show_otp_customer?
      @staff    = AppSetting.show_otp_staff?
    end

    def update
      key = params[:scope] == "staff" ? AppSetting::SHOW_OTP_STAFF_KEY : AppSetting::SHOW_OTP_CUSTOMER_KEY
      AppSetting.set_flag(key, params[:on])
      redirect_to admin_settings_path, notice: "Đã cập nhật công tắc hiện OTP."
    end

    private

    def nav_key = :settings
  end
end
