module Admin
  # Super admin manages their own login (name / email / password). Requires the
  # current password for any change.
  class AccountController < BaseController
    def edit
      @admin = current_admin_user
    end

    def update
      @admin = current_admin_user
      if @admin.update_with_password(account_params)
        bypass_sign_in(@admin, scope: :admin_user)
        redirect_to admin_account_path, notice: "Đã cập nhật tài khoản."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def nav_key = :account

    def account_params
      params.require(:admin_user).permit(:name, :email, :password, :password_confirmation, :current_password)
    end
  end
end
