module Merchant
  # Nhân sự: KTV, lễ tân, tư vấn, quản lý. Đa số KTV không có tài khoản đăng
  # nhập nhưng vẫn phải xếp ca và tính hoa hồng, nên bản ghi nhân sự tách khỏi
  # tài khoản người dùng.
  class StaffMembersController < BaseController
    before_action :require_manager!, except: [:index, :show]
    before_action :set_staff, only: [:show, :edit, :update, :archive, :reactivate, :skills]

    def index
      scope = current_workspace.staff_members.includes(:branch, :staff_level)
      scope = scope.at_branch(current_branch&.id)
      scope = scope.where(role: params[:role]) if StaffMember::ROLES.include?(params[:role])
      @status = params[:status].presence || "active"
      scope = scope.where(status: @status) if StaffMember::STATUSES.include?(@status)
      @staff = scope.ordered.to_a
      @counts = current_workspace.staff_members.group(:status).count
      @role_counts = current_workspace.staff_members.active.group(:role).count
    end

    def show
      @shift_templates = @staff.shift_templates.ordered.to_a
      @new_template = @staff.shift_templates.new
      @upcoming_shifts = @staff.staff_shifts.between(Date.current, 13.days.from_now).ordered.to_a
      @branches = current_workspace.branches.ordered.to_a
      @services = current_workspace.services.main.active.ordered.to_a
      @skill_ids = @staff.staff_services.pluck(:service_id)
    end

    def new
      unless current_workspace.can_add_staff?
        return redirect_to merchant_staff_index_path,
          alert: "Đã đạt giới hạn #{current_workspace.staff_limit} nhân sự của gói #{current_workspace.plan_record.name}."
      end
      @staff = current_workspace.staff_members.new(role: "therapist", status: "active",
                                                   branch_id: current_branch&.id || current_workspace.branches.first&.id)
      load_options
    end

    def create
      @staff = current_workspace.staff_members.new(staff_params)
      unless current_workspace.can_add_staff?
        @staff.errors.add(:base, "Đã đạt giới hạn nhân sự của gói hiện tại.")
        load_options
        return render :new, status: :unprocessable_entity
      end
      if @staff.save
        sync_branches
        audit!("staff.create", target: @staff, summary: @staff.display_name)
        redirect_to merchant_staff_path(@staff), notice: "Đã thêm nhân sự."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit = load_options

    def update
      if @staff.update(staff_params)
        sync_branches
        audit!("staff.update", target: @staff, summary: @staff.display_name)
        redirect_to merchant_staff_path(@staff), notice: "Đã lưu nhân sự."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    # Nhân sự nghỉ việc: giữ toàn bộ lịch sử ca làm và hoa hồng, chỉ ngưng xếp ca.
    def archive
      @staff.update!(status: "inactive", left_at: Date.current, online_bookable: false)
      audit!("staff.archive", target: @staff, summary: @staff.display_name)
      redirect_to merchant_staff_index_path, notice: "Đã cho #{@staff.name} nghỉ việc."
    end

    def reactivate
      @staff.update!(status: "active", left_at: nil)
      redirect_to merchant_staff_path(@staff), notice: "Đã nhận #{@staff.name} trở lại."
    end

    # Kỹ năng: KTV này làm được dịch vụ nào. Để TRỐNG nghĩa là làm được tất cả —
    # spa nhỏ không phải khai ma trận kỹ năng trước khi nhận khách đầu tiên.
    def skills
      ids = Array(params[:service_ids]).map(&:to_i).reject(&:zero?)
      @staff.staff_services.where.not(service_id: ids).destroy_all
      (ids - @staff.staff_services.pluck(:service_id)).each do |sid|
        @staff.staff_services.create!(workspace: current_workspace, service_id: sid)
      end
      audit!("staff.skills", target: @staff, summary: "#{ids.size} dịch vụ")
      redirect_to merchant_staff_path(@staff), notice: "Đã lưu kỹ năng của #{@staff.name}."
    end

    private

    def set_staff = @staff = current_workspace.staff_members.find(params[:id])

    def load_options
      @branches = current_workspace.branches.where.not(status: "archived").ordered.to_a
      @levels   = current_workspace.staff_levels.ordered.to_a
      @users    = current_workspace.users.order(:name).to_a
    end

    # Chi nhánh phụ. Chi nhánh chính nằm ở branch_id.
    def sync_branches
      allowed = current_workspace.branches.pluck(:id)
      ids = Array(params[:extra_branch_ids]).map(&:to_i)
                                            .select { |i| allowed.include?(i) }
                                            .reject { |i| i == @staff.branch_id }
      @staff.staff_branches.where.not(branch_id: ids).destroy_all
      (ids - @staff.staff_branches.pluck(:branch_id)).each do |bid|
        @staff.staff_branches.create!(workspace: current_workspace, branch_id: bid)
      end
    end

    def staff_params
      permitted = params.require(:staff_member).permit(
        :branch_id, :user_id, :staff_level_id, :code, :name, :nickname,
        :phone, :email, :gender, :dob, :role, :employment_type,
        :hired_at, :status, :base_salary, :commission_percent,
        :online_bookable, :max_daily_minutes, :calendar_color, :bio, :avatar
      )
      # `user_id` và `branch_id` đến từ form nên phải kiểm tra lại là của CHÍNH
      # workspace này. Không kiểm thì một quản lý sửa được id trong request và
      # gắn bản ghi nhân sự vào tài khoản của spa khác.
      permitted[:user_id] = nil unless current_workspace.users.exists?(id: permitted[:user_id])
      unless permitted[:branch_id].blank? || current_workspace.branches.exists?(id: permitted[:branch_id])
        permitted[:branch_id] = nil
      end
      permitted
    end

    def nav_key = :staff
  end
end
