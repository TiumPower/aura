module Admin
  class WorkspacesController < BaseController
    before_action :set_workspace, only: [:show, :update, :approve, :suspend, :reactivate, :destroy, :impersonate]

    def index
      ActsAsTenant.without_tenant do
        scope = Workspace.order(created_at: :desc)
        @status = params[:status] if Workspace::STATUSES.include?(params[:status])
        scope = scope.where(status: @status) if @status
        all = scope.to_a
        @counts = Workspace.group(:status).count
        @payment = params[:payment].to_sym if Workspace::PAYMENT_STATES.map(&:to_s).include?(params[:payment])
        @pay_counts = all.group_by(&:payment_state).transform_values(&:size)
        all = all.select { |w| w.payment_state == @payment } if @payment
        @workspaces = all
        # Số cơ sở / nhân sự của từng workspace cho bảng danh sách, mỗi thứ một truy vấn.
        @branch_counts = Branch.unscoped.group(:workspace_id).count
        @staff_counts  = StaffMember.unscoped.where(status: "active").group(:workspace_id).count
      end
    end

    def new
      @workspace = Workspace.new(status: "active", plan: "starter")
    end

    # Admin creates a workspace + its owner login.
    def create
      @workspace = Workspace.new(create_params)
      @workspace.status ||= "active"
      @workspace.plan   ||= "starter"
      @workspace.settings = { "onboarded" => true }
      @email = params[:owner_email].to_s.downcase.strip
      @owner_name = params[:owner_name].presence || "Chủ #{@workspace.name}"

      unless valid_admin_create?
        return render :new, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        @workspace.save!
        owner = User.find_or_initialize_by(email: @email)
        if owner.new_record?
          owner.assign_attributes(name: @owner_name, password: SecureRandom.hex(16), locale: "vi")
          owner.save!
        end
        ActsAsTenant.with_tenant(@workspace) { @workspace.memberships.create!(user: owner, role: "owner") }
        WorkspaceBootstrap.call(@workspace)
      end
      redirect_to admin_workspace_path(@workspace),
                  notice: "Đã tạo workspace #{@workspace.name}. Owner đăng nhập bằng email: #{@email}"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def show
      ActsAsTenant.with_tenant(@workspace) do
        @branches_count = Branch.count
        @rooms_count    = Room.count
        @staff_count    = StaffMember.where(status: "active").count
        @members_count  = Member.count
        @branches       = Branch.ordered.to_a
      end
    end

    def update
      if @workspace.update(update_params)
        redirect_to admin_workspace_path(@workspace), notice: "Đã cập nhật workspace."
      else
        ActsAsTenant.with_tenant(@workspace) do
          @branches_count = Branch.count
          @rooms_count    = Room.count
          @staff_count    = StaffMember.where(status: "active").count
          @members_count  = Member.count
          @branches       = Branch.ordered.to_a
        end
        render :show, status: :unprocessable_entity
      end
    end

    def approve    = transition("active",    "Đã duyệt workspace.")
    def suspend    = transition("suspended", "Đã tạm ngưng workspace.")
    def reactivate = transition("active",    "Đã kích hoạt lại workspace.")

    # Open the landlord's dashboard AS that landlord (support/impersonation).
    def impersonate
      owner = @workspace.owner
      return redirect_back(fallback_location: admin_workspace_path(@workspace), alert: "Workspace chưa có chủ spa.") if owner.nil?
      sign_in(:user, owner)
      session[:workspace_id] = @workspace.id
      session[:impersonator_admin_id] = current_admin_user.id
      redirect_to merchant_url_for(@workspace, "/merchant"), allow_other_host: true
    end

    def destroy
      name = @workspace.name
      WorkspacePurge.call(@workspace)
      redirect_to admin_workspaces_path,
                  notice: "Đã xoá vĩnh viễn workspace “#{name}” và toàn bộ dữ liệu liên quan."
    end

    private

    def nav_key = :workspaces

    def set_workspace
      ActsAsTenant.without_tenant { @workspace = Workspace.friendly.find(params[:id]) }
    end

    def transition(status, msg)
      @workspace.update!(status: status)
      redirect_back fallback_location: admin_workspaces_path, notice: msg
    end

    def create_params
      params.require(:workspace).permit(:name, :subdomain, :status, :plan, :locale_default)
    end

    def update_params
      params.require(:workspace).permit(:name, :subdomain, :custom_domain, :status, :plan, :locale_default)
    end

    def valid_admin_create?
      ok = @workspace.valid?
      if TenantResolver::RESERVED_SUBDOMAINS.include?(@workspace.subdomain.to_s.downcase)
        @workspace.errors.add(:subdomain, "không sử dụng được (đã dành riêng)"); ok = false
      end
      if @email.blank? || !@email.include?("@")
        @workspace.errors.add(:base, "Email owner không hợp lệ"); ok = false
      end
      ok
    end
  end
end
