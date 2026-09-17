module Merchant
  # Phòng / giường / ghế. `capacity` là số khách phục vụ đồng thời, nên một khu
  # foot 6 ghế là MỘT phòng capacity 6 thay vì 6 bản ghi.
  class RoomsController < BaseController
    before_action :require_manager!, except: [:index, :show]
    before_action :set_room, only: [:show, :edit, :update, :destroy, :status]

    def index
      scope = current_workspace.rooms.includes(:branch, :room_type)
      @rooms = by_branch(scope).ordered.to_a
      @branches = current_workspace.branches.ordered.to_a
      @capacity = @rooms.select(&:active?).sum(&:capacity)
    end

    def show
      redirect_to merchant_branch_path(@room.branch)
    end

    def new
      @branch = current_workspace.branches.friendly.find(params[:branch_id])
      @room = @branch.rooms.new(capacity: 1)
      @room_types = current_workspace.room_types.ordered.to_a
    end

    def create
      @branch = current_workspace.branches.friendly.find(params[:branch_id])
      @room = @branch.rooms.new(room_params.merge(workspace: current_workspace))
      unless current_workspace.can_add_room?
        @room.errors.add(:base, "Đã đạt giới hạn số phòng của gói hiện tại.")
        @room_types = current_workspace.room_types.ordered.to_a
        return render :new, status: :unprocessable_entity
      end
      if @room.save
        audit!("room.create", target: @room, summary: "#{@branch.name} · #{@room.name}")
        redirect_to merchant_branch_path(@branch), notice: "Đã thêm phòng."
      else
        @room_types = current_workspace.room_types.ordered.to_a
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @room_types = current_workspace.room_types.ordered.to_a
    end

    def update
      if @room.update(room_params)
        audit!("room.update", target: @room, summary: @room.name)
        redirect_to merchant_branch_path(@room.branch), notice: "Đã lưu phòng."
      else
        @room_types = current_workspace.room_types.ordered.to_a
        render :edit, status: :unprocessable_entity
      end
    end

    # Đổi nhanh trạng thái phòng từ sơ đồ (bảo trì / dùng lại).
    def status
      value = Room::STATUSES.include?(params[:value]) ? params[:value] : "active"
      @room.update!(status: value)
      audit!("room.status", target: @room, summary: "#{@room.name} → #{@room.status_label}")
      redirect_back fallback_location: merchant_branch_path(@room.branch),
                    notice: "#{@room.name}: #{@room.status_label}."
    end

    def destroy
      branch = @room.branch
      @room.destroy
      audit!("room.destroy", summary: @room.name)
      redirect_to merchant_branch_path(branch), notice: "Đã xoá phòng."
    end

    private

    def set_room = @room = current_workspace.rooms.find(params[:id])

    def room_params
      params.require(:room).permit(:room_type_id, :name, :code, :capacity, :turnaround_minutes,
                                   :floor, :status, :online_bookable, :position, :notes)
    end

    def nav_key = :rooms
  end
end
