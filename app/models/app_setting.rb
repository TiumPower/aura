# Platform-level key/value store (not tenant-scoped). Used for rotating Zalo ZNS
# OA tokens, and for platform switches the super admin flips at runtime (see
# `flag?`) — anything that must change without a deploy or an .env edit.
class AppSetting < ApplicationRecord
  def self.get(key) = find_by(key: key.to_s)&.value

  def self.set(key, value)
    rec = find_or_initialize_by(key: key.to_s)
    rec.update!(value: value.to_s)
    value
  end

  # --- Boolean switches ----------------------------------------------------
  # A flag is only "on" when it was explicitly turned on; a missing row is off.
  def self.flag?(key)
    get(key) == "true"
  rescue ActiveRecord::StatementInvalid
    # The table may not exist yet during an early boot / first migration.
    false
  end

  def self.set_flag(key, on)
    set(key, ActiveModel::Type::Boolean.new.cast(on) ? "true" : "false")
  end

  # Hiện mã OTP thẳng trên màn hình thay vì chỉ gửi đi. Dùng để test/demo.
  #
  # Hai cờ RIÊNG, cố ý: bật cho cổng nhân sự là ai biết email một nhân viên cũng
  # vào được toàn bộ dữ liệu spa, còn khách chỉ thấy dữ liệu của chính họ.
  SHOW_OTP_CUSTOMER_KEY = "show_otp_customer".freeze
  SHOW_OTP_STAFF_KEY    = "show_otp_staff".freeze

  def self.show_otp_customer? = flag?(SHOW_OTP_CUSTOMER_KEY)
  def self.show_otp_staff?    = flag?(SHOW_OTP_STAFF_KEY)
  def self.show_otp_any?      = show_otp_customer? || show_otp_staff?
end
