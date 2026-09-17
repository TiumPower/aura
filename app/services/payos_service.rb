# PayOS payment-gateway client (mirrors VOX). Uses Faraday.
class PayosService
  BASE_URL = "https://api-merchant.payos.vn"

  def initialize
    @client_id    = ENV.fetch("PAYOS_CLIENT_ID", "")
    @api_key      = ENV.fetch("PAYOS_API_KEY", "")
    @checksum_key = ENV.fetch("PAYOS_CHECKSUM_KEY", "")
  end

  def configured? = @client_id.present? && @api_key.present? && @checksum_key.present?

  # Create a payment link. Returns data hash (checkoutUrl, qrCode, orderCode…) or nil.
  def create_payment_link(order_code:, amount:, description:, return_url:, cancel_url:)
    payload = {
      orderCode:   order_code,
      amount:      amount.to_i,
      description: description.to_s[0, 25],
      returnUrl:   return_url,
      cancelUrl:   cancel_url
    }
    payload[:signature] = sign_create(payload)

    resp = conn.post("/v2/payment-requests") do |req|
      req.headers.merge!(headers)
      req.body = payload.to_json
    end
    parsed = parse(resp.body)
    return nil unless parsed.is_a?(Hash) && parsed["code"] == "00"
    parsed["data"]
  rescue => e
    Rails.logger.error("[PayOS] create_payment_link: #{e.class}: #{e.message}")
    nil
  end

  def get_payment_info(order_code)
    resp = conn.get("/v2/payment-requests/#{order_code}") { |req| req.headers.merge!(headers) }
    parsed = parse(resp.body)
    return nil unless parsed.is_a?(Hash) && parsed["code"] == "00"
    parsed["data"]
  rescue => e
    Rails.logger.error("[PayOS] get_payment_info: #{e.class}: #{e.message}")
    nil
  end

  # Verify a webhook payload (parsed JSON hash). Signature is at the root.
  def verify_webhook(payload)
    data = payload["data"]
    return false unless data.is_a?(Hash)
    ActiveSupport::SecurityUtils.secure_compare(payload["signature"].to_s, sign_webhook(data))
  end

  private

  def conn
    @conn ||= Faraday.new(url: BASE_URL) { |f| f.options.timeout = 12 }
  end

  def parse(body) = body.is_a?(String) ? JSON.parse(body) : body

  def headers
    { "x-client-id" => @client_id, "x-api-key" => @api_key, "Content-Type" => "application/json" }
  end

  def sign_create(p)
    str = "amount=#{p[:amount]}&cancelUrl=#{p[:cancelUrl]}&description=#{p[:description]}" \
          "&orderCode=#{p[:orderCode]}&returnUrl=#{p[:returnUrl]}"
    OpenSSL::HMAC.hexdigest("SHA256", @checksum_key, str)
  end

  def sign_webhook(data)
    sorted = data.except("signature").sort.map { |k, v| "#{k}=#{v}" }.join("&")
    OpenSSL::HMAC.hexdigest("SHA256", @checksum_key, sorted)
  end
end
