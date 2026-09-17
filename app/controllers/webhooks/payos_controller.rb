module Webhooks
  # PayOS server-to-server payment confirmation. No CSRF / no auth.
  class PayosController < ActionController::Base
    skip_forgery_protection

    # Always answer 200 so PayOS accepts the webhook URL (its registration test
    # ping and any unsigned request must not 401). We only ACT on a payload whose
    # signature verifies, so returning 200 for unverified pings is safe.
    def receive
      payload = JSON.parse(request.body.read) rescue {}
      if payload.present? && PayosService.new.verify_webhook(payload)
        process_payment(payload)
      else
        Rails.logger.info("[PayOS webhook] ping / unverified payload — acking 200")
      end
      render json: { success: true }
    rescue => e
      Rails.logger.error("[PayOS webhook] #{e.class}: #{e.message}")
      render json: { success: true }
    end

    private

    def process_payment(payload)
      order_code = payload.dig("data", "orderCode").to_i
      invoice = ActsAsTenant.without_tenant { Invoice.find_by(payos_order_code: order_code) }
      return unless invoice
      ActsAsTenant.with_tenant(invoice.workspace) do
        case payload["code"]
        when "00" then invoice.apply_payment!(gateway_response: payload)
        when "01", "02" then invoice.mark_failed!(gateway_response: payload)
        end
      end
    end
  end
end
