module Merchant
  # Tự đăng ký dùng thử: tạo workspace (kèm subdomain riêng) + tài khoản chủ
  # spa, rồi đưa thẳng vào thiết lập ban đầu.
  class SignupsController < ApplicationController
    layout "marketing"

    RESERVED = TenantResolver::RESERVED_SUBDOMAINS

    def new
      redirect_to(merchant_root_path) and return if user_signed_in?
      @workspace = Workspace.new(business_type: "massage")
    end

    def create
      @workspace = Workspace.new(workspace_params)
      @workspace.status     = "trial"
      @workspace.paid_until = Workspace::TRIAL_DAYS.days.from_now
      @workspace.plan       = "starter"
      @email = params[:email].to_s.strip.downcase
      @name  = params[:owner_name].presence || "Chủ spa"

      if reserved_subdomain?
        @workspace.errors.add(:subdomain, "không sử dụng được, vui lòng chọn tên khác")
        return render :new, status: :unprocessable_entity
      end
      return render :new, status: :unprocessable_entity unless valid_signup?

      ActiveRecord::Base.transaction do
        @workspace.save!
        owner = User.find_or_initialize_by(email: @email)
        if owner.new_record?
          owner.assign_attributes(name: @name, password: params[:password], locale: "vi")
          owner.save!
        end
        ActsAsTenant.with_tenant(@workspace) do
          @workspace.memberships.create!(user: owner, role: "owner")
        end
        WorkspaceBootstrap.call(@workspace)
        sign_in(:user, owner)
        session[:workspace_id] = @workspace.id
      end

      begin
        AdminMailer.new_workspace(@workspace).deliver_later
      rescue => e
        Rails.logger.error("[Signup] admin notify failed: #{e.class} #{e.message}")
      end

      redirect_to merchant_url_for(@workspace, "/merchant/onboarding"), allow_other_host: true,
                  notice: "Chào mừng! Bạn đang dùng thử #{Workspace::TRIAL_DAYS} ngày."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    private

    def workspace_params
      params.require(:workspace).permit(:name, :subdomain, :business_type)
    end

    def reserved_subdomain?
      RESERVED.include?(@workspace.subdomain.to_s.downcase)
    end

    def valid_signup?
      ok = @workspace.valid?
      if @email.blank? || !@email.include?("@")
        @workspace.errors.add(:base, "Email không hợp lệ"); ok = false
      end
      if params[:password].to_s.length < 6
        @workspace.errors.add(:base, "Mật khẩu tối thiểu 6 ký tự"); ok = false
      end
      ok
    end
  end
end
