class OtpMailer < ApplicationMailer
  # Works for both landlord logins (no workspace → platform brand) and tenant
  # logins (white-labelled with the landlord's workspace name).
  def login_code(challenge)
    @code      = challenge.code
    @workspace = challenge.workspace
    @brand     = @workspace&.name || "Aura"
    from_addr  = ENV.fetch("MAIL_FROM", "no-reply@aura.czin.net")
    mail(to: challenge.email,
         from: "#{@brand} <#{from_addr}>",
         subject: "#{@brand}: Mã đăng nhập #{@code}")
  end
end
