# Register the Brevo HTTP-API delivery method (used when BREVO_API_KEY is set).
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method(:brevo, BrevoMailDelivery)
end
