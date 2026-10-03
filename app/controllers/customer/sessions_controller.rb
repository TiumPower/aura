module Customer
  # Đăng nhập của khách: SỐ ĐIỆN THOẠI + OTP, trong phạm vi một spa.
  # SĐT là khoá hồ sơ CRM, nên khách walk-in mà lễ tân đã tạo hồ sơ sẽ đăng nhập
  # vào ĐÚNG hồ sơ đó — không sinh ra bản ghi thứ hai.
  class SessionsController < BaseController
    skip_before_action :enforce_member_status
    before_action :require_workspace!

    def new
      if member_signed_in? && current_member.workspace_id == current_workspace.id
        return redirect_to member_root_path
      end
      @phone = ""
    end

    def create
      @phone = Member.canonical_phone(params[:phone])
      unless @phone&.match?(/\A0\d{8,10}\z/)
        flash.now[:alert] = t("customer.session.phone_invalid")
        return render :new, status: :unprocessable_entity
      end
      OtpChallenge.issue!(identifier: @phone, scope: "customer", workspace: current_workspace)
      session[:otp_phone] = @phone
      redirect_to member_verify_path
    end

    def verify_form
      @phone = session[:otp_phone]
      redirect_to(member_login_path) and return if @phone.blank?
      load_challenge
    end

    def verify
      @phone = session[:otp_phone]
      redirect_to(member_login_path) and return if @phone.blank?

      challenge = OtpChallenge.latest_for(identifier: @phone, scope: "customer",
                                          workspace: current_workspace)
      result = challenge&.verify(params[:code])
      if result == :ok
        member = find_or_create_member(@phone)
        session.delete(:otp_phone)
        sign_in_member(member)
        member.update(last_seen_at: Time.current)
        redirect_to (session.delete(:return_to).presence || member_root_path),
                    notice: "Chào mừng quý khách đến với #{current_workspace.name} 🌿"
      else
        load_challenge
        flash.now[:alert] = otp_error_message(result)
        render :verify_form, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out_member
      redirect_to member_login_path, notice: "Đã đăng xuất."
    end

    private

    # Khách tự đăng nhập bằng số mà lễ tân đã tạo hồ sơ → dùng lại hồ sơ đó.
    def find_or_create_member(phone)
      existing = current_workspace.members.find_by(phone: phone)
      return existing if existing
      current_workspace.members.create!(phone: phone, source: "self_signup",
                                        locale: current_workspace.locale_default)
    end

    # Challenge quyết định cả hai việc: có in mã lên màn hình hay không, và có
    # phải giải thích một lần gửi thất bại hay không. Một quy tắc duy nhất, dùng
    # chung với cổng nhân sự — xem OtpChallenge#show_on_screen?.
    def load_challenge
      @challenge = OtpChallenge.latest_for(identifier: @phone, scope: "customer",
                                           workspace: current_workspace)
      @dev_code  = @challenge.code if @challenge&.show_on_screen?
      @emailed   = @challenge&.channel == "email" && @challenge.deliverable?
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
