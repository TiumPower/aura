# Basic abuse protection for auth endpoints (OTP + logins).
# Focused throttles only — no broad IP throttle, to avoid false-positives on
# the customer app's polling. Uses a shared Redis store across puma workers.
return unless defined?(Rack::Attack)

class Rack::Attack
  begin
    self.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      namespace: "rack_attack", error_handler: ->(*) {}
    )
  rescue StandardError => e
    Rails.logger.warn("[RackAttack] Redis store unavailable, using memory: #{e.class}")
  end

  safelist("localhost") { |req| %w[127.0.0.1 ::1].include?(req.ip) }

  customer_login = ->(req) { req.post? && req.path.end_with?("/login") && !req.path.start_with?("/merchant", "/admin") }

  # Customer OTP issue: limit per email (anti email-bomb) and per IP.
  throttle("otp/email", limit: 5, period: 10.minutes) do |req|
    if customer_login.call(req)
      email = req.params["email"].to_s.strip.downcase
      "otp-email:#{email}" if email.present?
    end
  end
  throttle("otp/ip", limit: 20, period: 10.minutes) { |req| req.ip if customer_login.call(req) }

  # Customer OTP verify: cap guesses per IP (model already caps per challenge).
  throttle("otp-verify/ip", limit: 30, period: 10.minutes) do |req|
    req.ip if req.post? && req.path.end_with?("/verify")
  end

  # Merchant / Admin login (password): cap attempts per IP.
  throttle("login/ip", limit: 15, period: 20.minutes) do |req|
    req.ip if req.post? && %w[/merchant/login /admin/login].include?(req.path)
  end

  # Public listing enquiry: unauthenticated, and every submission emails the
  # landlord through Brevo. Nothing capped it, so one script could bury a
  # landlord's inbox and burn the mail quota.
  lead_form = ->(req) { req.post? && req.path.start_with?("/u/") && req.path.end_with?("/inquiry") }
  throttle("lead/ip", limit: 5, period: 10.minutes) { |req| req.ip if lead_form.call(req) }
  throttle("lead/unit", limit: 20, period: 1.hour) { |req| req.path if lead_form.call(req) }

  self.throttled_responder = lambda do |req|
    period = (req.env["rack.attack.match_data"] || {})[:period]
    [429, { "Content-Type" => "text/plain", "Retry-After" => period.to_s },
     ["Quá nhiều yêu cầu. Vui lòng thử lại sau ít phút. / Too many requests. Please try again shortly."]]
  end
end
