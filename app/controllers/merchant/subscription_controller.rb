module Merchant
  # SaaS subscription payments (landlord pays for their Aura plan via PayOS).
  # Separate from Merchant::PaymentsController, which handles tenant bill proofs.
  class SubscriptionController < BaseController
    before_action :require_manager!

    PLAN_KEYS = Plan::DEFAULTS.map { |d| d[:key] }.freeze

    # "Thanh toán" — find/create the pending invoice for the right period, then
    # open a fresh PayOS checkout. The plan being paid for lives on the INVOICE;
    # the workspace only switches when payment succeeds (Invoice#apply_payment!).
    def create
      ws = current_workspace
      chosen = PLAN_KEYS.include?(params[:plan]) ? params[:plan] : ws.plan
      # Same quote the billing page showed on the button — see Workspace#checkout_quote.
      amount, start_d, end_d = ws.checkout_quote(chosen)

      invoice = ws.invoices.pending.order(:period_start).first
      if invoice && (invoice.plan != chosen || invoice.amount != amount)
        invoice.update!(plan: chosen, amount: amount, period_start: start_d, period_end: end_d)
      end
      unless invoice
        if chosen == ws.plan && start_d > Date.current && ws.subscription_active? && !ws.trial?
          return redirect_to merchant_billing_path,
            notice: "Gói đang còn hiệu lực đến #{ws.paid_until.to_date.strftime('%d/%m/%Y')}. Hoá đơn kỳ mới sẽ được tạo khi đến hạn."
        end
        invoice = ws.invoices.create!(plan: chosen, amount: amount,
                                      period_start: start_d, period_end: end_d, status: "pending")
      end
      start_checkout(invoice)
    end

    # "Trả tiếp" — resume an existing pending invoice with a NEW PayOS link.
    def repay
      invoice = current_workspace.invoices.pending.find(params[:id])
      start_checkout(invoice)
    end

    # PayOS redirects here after payment/cancel; confirm with PayOS directly in
    # case the webhook hasn't landed yet.
    def return
      order_code = (params[:orderCode].presence || params[:code]).to_i
      @workspace = current_workspace
      @invoice = current_workspace.invoices.find_by(payos_order_code: order_code)
      if @invoice&.pending?
        info = PayosService.new.get_payment_info(order_code)
        if info && info["status"] == "PAID"
          @invoice.apply_payment!(gateway_response: info)
        elsif params[:cancel] == "true" || params[:status] == "CANCELLED" || info&.dig("status") == "CANCELLED"
          @invoice.update!(status: "cancelled")
        end
      end
    end

    def auto_renew
      current_workspace.update(auto_renew: params[:auto_renew] == "1")
      redirect_to merchant_billing_path,
        notice: current_workspace.auto_renew ? "Đã bật tự động tạo hoá đơn hàng tháng." : "Đã tắt tự động gia hạn."
    end

    private

    def nav_key = :billing

    # Always mint a fresh order code + link so a stale/cancelled PayOS order can
    # never block a retry, then send the merchant to the checkout.
    def start_checkout(invoice)
      service = PayosService.new
      unless service.configured?
        return redirect_to merchant_billing_path, alert: "Cổng thanh toán PayOS chưa được cấu hình."
      end
      invoice.reassign_order_code!
      data = service.create_payment_link(
        order_code:  invoice.payos_order_code,
        amount:      invoice.amount,
        description: "Aura #{invoice.plan}",
        return_url:  merchant_billing_return_url(code: invoice.payos_order_code),
        cancel_url:  merchant_billing_return_url(code: invoice.payos_order_code, cancel: true)
      )
      if data && data["checkoutUrl"].present?
        invoice.update!(checkout_url: data["checkoutUrl"])
        redirect_to data["checkoutUrl"], allow_other_host: true
      else
        redirect_to merchant_billing_path, alert: "Không tạo được liên kết thanh toán. Thử lại sau."
      end
    end
  end
end
