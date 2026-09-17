# Whether email OTP delivery is configured (SMTP). When false, the OTP is shown
# on-screen instead (dev / not-yet-configured).
module EmailOtp
  module_function

  def configured?
    ENV["BREVO_API_KEY"].present? ||
      (ENV["SMTP_ADDRESS"].present? && ENV["SMTP_USERNAME"].present?)
  end
end
