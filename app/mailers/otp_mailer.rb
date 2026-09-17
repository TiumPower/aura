class OtpMailer < ApplicationMailer
  # Dùng cho cả nhân sự (không có workspace → thương hiệu nền tảng) và khách
  # (gắn thương hiệu spa).
  #
  # Địa chỉ nhận lấy từ `challenge.delivery_email`: với nhân sự đó chính là
  # identifier (email), còn với khách thì identifier là SĐT nên phải tra email
  # trong hồ sơ. Dùng thẳng `identifier` sẽ gửi mail tới một số điện thoại.
  def login_code(challenge)
    @code      = challenge.code
    @workspace = challenge.workspace
    @brand     = @workspace&.name || "Aura"
    to_addr    = challenge.delivery_email
    return if to_addr.blank?

    from_addr = ENV.fetch("MAIL_FROM", "no-reply@aura.czin.net")
    mail(to: to_addr,
         from: "#{@brand} <#{from_addr}>",
         subject: "#{@brand}: Mã đăng nhập #{@code}")
  end
end
