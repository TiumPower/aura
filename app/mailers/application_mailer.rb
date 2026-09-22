class ApplicationMailer < ActionMailer::Base
  default from: %(Aura <#{ENV.fetch("MAIL_FROM", "no-reply@aura.tiumpower.com")}>)
  layout "mailer"
end
