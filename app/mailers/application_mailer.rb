class ApplicationMailer < ActionMailer::Base
  default from: %(Aura <#{ENV.fetch("MAIL_FROM", "no-reply@aura.czin.net")}>)
  layout "mailer"
end
