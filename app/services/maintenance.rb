# Dọn dẹp định kỳ, chạy hằng ngày bởi MaintenanceJob (sidekiq-cron).
# Chạy xuyên tenant — luôn chạy ngoài phạm vi một spa.
module Maintenance
  module_function

  def run_all
    { otp_pruned: prune_otp_challenges }
  end

  # Chưa có gì xoá mã đăng nhập đã dùng/đã hết hạn, nên bảng cứ phình ra để
  # giữ dữ liệu vô dụng sau mười phút. Giữ lại một ngày để còn tra được khi
  # khách báo "không nhận được mã".
  OTP_TTL = 1.day

  def prune_otp_challenges
    n = OtpChallenge.unscoped.where("expires_at < ?", OTP_TTL.ago).delete_all
    Rails.logger.info("[Maintenance] đã xoá #{n} mã OTP hết hạn")
    n
  end
end
