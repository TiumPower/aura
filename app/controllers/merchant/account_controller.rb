module Merchant
  # A landlord/staff user edits their own profile (name, phone). Login is OTP,
  # so there is no password to manage here.
  class AccountController < BaseController
    def show
      @user = current_user
    end

    def update
      @user = current_user
      if params.dig(:user, :password).present?
        if @user.update(password_params)
          bypass_sign_in(@user, scope: :user)
          redirect_to merchant_account_path, notice: "Đã đổi mật khẩu."
        else
          render :show, status: :unprocessable_entity
        end
      elsif @user.update(account_params)
        redirect_to merchant_account_path, notice: "Đã cập nhật tài khoản."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def account_params
      params.require(:user).permit(:name, :phone, :locale)
    end

    def password_params
      params.require(:user).permit(:password, :password_confirmation)
    end

    def nav_key = :account
  end
end
