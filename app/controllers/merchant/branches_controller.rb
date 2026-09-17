module Merchant
  # Cơ sở của spa. Phòng, KTV, ca làm, lịch hẹn và số liệu đều treo vào đây.
  class BranchesController < BaseController
    before_action :require_manager!, except: [:index, :show]
    before_action :set_branch, only: [:show, :edit, :update, :destroy, :archive]

    def index
      @branches = current_workspace.branches.where.not(status: "archived").ordered.to_a
      @archived = current_workspace.branches.where(status: "archived").ordered.to_a
      ids = (@branches + @archived).map(&:id)
      @room_counts  = current_workspace.rooms.where(branch_id: ids).group(:branch_id).count
      @staff_counts = current_workspace.staff_members.active.where(branch_id: ids).group(:branch_id).count
      @capacity = current_workspace.rooms.active.where(branch_id: ids).group(:branch_id).sum(:capacity)
    end

    def show
      @rooms = @branch.rooms.includes(:room_type).ordered.to_a
      @hours = @branch.branch_hours.ordered.to_a
      @closures = @branch.branch_closures.upcoming.to_a
      @staff = current_workspace.staff_members.active.at_branch(@branch.id).ordered.to_a
      @room_types = current_workspace.room_types.ordered.to_a
      @new_room = @branch.rooms.new(capacity: 1)
      @new_closure = @branch.branch_closures.new(starts_on: Date.current, ends_on: Date.current)
    end

    def new
      unless current_workspace.plan_allows?(:multi_branch) || current_workspace.branches.empty?
        return redirect_to merchant_branches_path,
          alert: "Gói hiện tại chỉ dùng được 1 cơ sở. Nâng gói để mở thêm cơ sở."
      end
      unless current_workspace.can_add_branch?
        return redirect_to merchant_branches_path,
          alert: "Đã đạt giới hạn số cơ sở của gói #{current_workspace.plan_record.name}."
      end
      @branch = current_workspace.branches.new
    end

    def create
      @branch = current_workspace.branches.new(branch_params)
      unless current_workspace.can_add_branch?
        @branch.errors.add(:base, "Đã đạt giới hạn số cơ sở của gói hiện tại.")
        return render :new, status: :unprocessable_entity
      end
      if @branch.save
        @branch.ensure_hours!
        audit!("branch.create", target: @branch, summary: @branch.name)
        redirect_to merchant_branch_path(@branch), notice: "Đã tạo cơ sở."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @branch.update(branch_params)
        audit!("branch.update", target: @branch, summary: @branch.name)
        redirect_to merchant_branch_path(@branch), notice: "Đã lưu cơ sở."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Đóng cơ sở nhưng GIỮ dữ liệu — cơ sở đã có lịch sử thì không xoá.
    def archive
      @branch.update!(status: "archived")
      audit!("branch.archive", target: @branch, summary: @branch.name)
      redirect_to merchant_branches_path, notice: "Đã đóng cơ sở #{@branch.name}."
    end

    def destroy
      if @branch.rooms.exists? || current_workspace.staff_members.where(branch_id: @branch.id).exists?
        return redirect_to merchant_branch_path(@branch),
          alert: "Cơ sở còn phòng hoặc nhân sự — hãy đóng cơ sở thay vì xoá."
      end
      name = @branch.name
      @branch.destroy
      audit!("branch.destroy", summary: name)
      redirect_to merchant_branches_path, notice: "Đã xoá cơ sở."
    end

    private

    def set_branch = @branch = current_workspace.branches.friendly.find(params[:id])

    def branch_params
      params.require(:branch).permit(:name, :code, :phone, :address_line, :ward, :district, :city,
                                     :lat, :lng, :description, :directions, :status,
                                     :online_bookable, :position, :cover)
    end

    def nav_key = :branches
  end
end
