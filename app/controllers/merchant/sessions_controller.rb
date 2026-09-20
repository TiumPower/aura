module Merchant
  # Đăng nhập nhân sự: email + OTP (hoặc mật khẩu). Ở cấp nền tảng (workspace_id NULL
  # on the challenge); after verify we land the owner on their workspace.
  class SessionsController < ApplicationController
    layout "auth"

    # Step 1 — enter email (+ password, or switch to OTP)
    def new
      redirect_to(after_login_url, allow_other_host: true) and return if user_signed_in?
      @email = ""
      @otp   = params[:otp] == "1" # OTP mode toggled by the "đăng nhập bằng mã" link
    end

    # Step 1 submit — password login, or issue an OTP.
    def create
      @email = normalize(params[:email])
      @otp   = params[:mode] == "otp" || params[:password].blank?
      unless @email&.match?(URI::MailTo::EMAIL_REGEXP)
        flash.now[:alert] = "Vui lòng nhập email hợp lệ."
        return render :new, status: :unprocessable_entity
      end
      user = User.find_by(email: @email)
      unless user
        flash.now[:alert] = "Email này chưa có tài khoản. Vui lòng đăng ký."
        return render :new, status: :unprocessable_entity
      end

      if params[:mode] == "otp"
        OtpChallenge.issue!(identifier: @email, scope: "merchant")
        session[:merchant_otp_email] = @email
        redirect_to merchant_verify_path
      elsif user.valid_password?(params[:password].to_s)
        sign_in(:user, user)
        redirect_to after_login_url, allow_other_host: true, notice: "Chào mừng trở lại 👋"
      else
        flash.now[:alert] = "Mật khẩu không đúng. Bạn có thể đăng nhập bằng mã OTP."
        render :new, status: :unprocessable_entity
      end
    end

    # Log in by scanning the QR from the profile (on a phone). The token is a
    # short-lived signed id; the session is then remembered long-term so the
    # điện thoại của nhân sự vẫn giữ đăng nhập trong PWA.
    def qr_login
      user = User.find_signed(params[:token], purpose: :merchant_qr_login)
      if user
        user.remember_me = true # Devise sets the long-lived remember cookie on sign_in
        sign_in(:user, user)
        redirect_to after_login_url, allow_other_host: true, notice: "Đăng nhập thành công 📱"
      else
        redirect_to merchant_login_path, alert: "Mã QR đã hết hạn hoặc không hợp lệ. Hãy mở lại QR trên máy tính."
      end
    end

    # Step 2 — enter OTP
    def verify_form
      @email = session[:merchant_otp_email]
      redirect_to(merchant_login_path) and return if @email.blank?
      @dev_code = latest_dev_code(@email) if show_otp_onscreen?
    end

    # Step 2 submit — check OTP, sign in
    def verify
      @email = session[:merchant_otp_email]
      redirect_to(merchant_login_path) and return if @email.blank?

      challenge = OtpChallenge.latest_for(identifier: @email, scope: "merchant")
      result = challenge&.verify(params[:code])
      if result == :ok
        user = User.find_by(email: @email)
        session.delete(:merchant_otp_email)
        sign_in(:user, user)
        redirect_to after_login_url, allow_other_host: true, notice: "Chào mừng trở lại 👋"
      else
        @dev_code = latest_dev_code(@email) if show_otp_onscreen?
        flash.now[:alert] = otp_error_message(result)
        render :verify_form, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out(:user)
      redirect_to merchant_login_path, notice: "Đã đăng xuất."
    end

    # Super admin ends an impersonation session and returns to the admin.
    def stop_impersonation
      ws_id = session[:workspace_id]
      sign_out(:user)
      session.delete(:impersonator_admin_id)
      ws = Workspace.find_by(id: ws_id)
      target = ws ? "https://#{PLATFORM_HOST}/admin/workspaces/#{ws.to_param}" : "https://#{PLATFORM_HOST}/admin"
      redirect_to target, allow_other_host: true, notice: "Đã thoát chế độ xem chủ spa."
    end

    private

    # Đây là URL TUYỆT ĐỐI sang subdomain của spa (không phải path), nên mọi
    # redirect tới nó phải mang `allow_other_host: true`: Rails 7 chặn redirect
    # chéo host, và trong dev thì `merchant_url_for` trả về path tương đối nên
    # lỗi chỉ lộ ra trên production — đăng nhập quản lý ở host gốc chết 500.
    # Host được dựng từ `workspace.subdomain` của chính mình, không từ tham số
    # người dùng gửi lên, nên mở host khác ở đây là an toàn.
    def after_login_url
      ws = current_user&.workspaces&.order(:created_at)&.first
      merchant_url_for(ws, "/merchant")
    end

    def normalize(email) = email.to_s.strip.downcase

    def show_otp_onscreen?
      AppSetting.show_otp_staff? || ENV["SHOW_OTP"] == "true" ||
        !Rails.env.production? || !EmailOtp.configured?
    end

    def latest_dev_code(email)
      OtpChallenge.latest_for(identifier: email, scope: "merchant")&.code
    end

    def otp_error_message(result)
      case result
      when :expired  then "Mã đã hết hạn. Vui lòng gửi lại."
      when :too_many then "Nhập sai quá nhiều lần. Vui lòng gửi lại mã."
      else "Mã xác thực không đúng."
      end
    end
  end
end
