module Merchant
  # Landlord's bank details used to generate VietQR on tenant bills.
  class PaymentSettingsController < BaseController
    def show
      @bank = current_workspace.bank
    end

    def update
      code = params[:bank_code].to_s
      # Nothing validated these before, so "abc-xyz" saved happily and every
      # bill then carried a VietQR embedding it — tenants scanning a code that
      # pays nowhere, with the landlord told "Đã lưu thông tin thanh toán".
      account_no = params[:account_no].to_s.strip
      errors = []
      errors << "Vui lòng chọn ngân hàng." if code.blank?
      if account_no.blank?
        errors << "Vui lòng nhập số tài khoản."
      elsif !account_no.match?(/\A\d{6,20}\z/)
        errors << "Số tài khoản chỉ gồm chữ số (6–20 số). Bạn đang nhập: “#{account_no}”."
      end

      if errors.any?
        @bank = current_workspace.bank.merge(
          "code" => code, "account_no" => account_no,
          "account_name" => params[:account_name].to_s.strip
        )
        flash.now[:alert] = errors.join(" ")
        return render :show, status: :unprocessable_entity
      end

      bank = {
        "code" => code,
        "bin" => VietQrService.bin_for(code) || params[:bin].to_s,
        "account_no" => account_no,
        # VietQR expects the holder name unaccented and upper-case; a landlord
        # typing "Nguyễn Văn Chủ" would otherwise ship diacritics into the code.
        "account_name" => normalize_holder(params[:account_name])
      }
      current_workspace.settings = current_workspace.settings.merge("bank" => bank)
      if current_workspace.save
        current_workspace.static_qr.attach(params[:static_qr]) if params[:static_qr].present?
        current_workspace.static_qr.purge if params[:remove_static_qr] == "1"
        redirect_to merchant_payment_settings_path, notice: "Đã lưu thông tin thanh toán."
      else
        @bank = bank
        flash.now[:alert] = current_workspace.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    private

    def normalize_holder(name)
      I18n.transliterate(name.to_s).upcase.gsub(/[^A-Z0-9 ]/, " ").squish
    end

    def nav_key = :payment
  end
end
