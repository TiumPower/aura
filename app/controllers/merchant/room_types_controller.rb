module Merchant
  # Loại phòng do từng spa tự định nghĩa — dịch vụ sẽ khai mình chạy ở loại nào.
  class RoomTypesController < BaseController
    before_action :require_manager!
    before_action :set_room_type, only: [:edit, :update, :destroy]

    def index
      @room_types = current_workspace.room_types.ordered.to_a
      @counts = current_workspace.rooms.group(:room_type_id).count
      @room_type = current_workspace.room_types.new(default_capacity: 1)
      @presets = RoomType.presets_for(current_workspace.business_type)
                         .reject { |p| current_workspace.room_types.exists?(key: p[:key]) }
    end

    def new = redirect_to merchant_room_types_path

    def create
      @room_type = current_workspace.room_types.new(room_type_params)
      if @room_type.save
        redirect_to merchant_room_types_path, notice: "Đã thêm loại phòng."
      else
        @room_types = current_workspace.room_types.ordered.to_a
        @counts = current_workspace.rooms.group(:room_type_id).count
        @presets = []
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @room_type.update(room_type_params)
        redirect_to merchant_room_types_path, notice: "Đã lưu loại phòng."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if current_workspace.rooms.exists?(room_type_id: @room_type.id)
        return redirect_to merchant_room_types_path,
          alert: "Còn phòng đang dùng loại này — hãy chuyển phòng sang loại khác trước."
      end
      @room_type.destroy
      redirect_to merchant_room_types_path, notice: "Đã xoá loại phòng."
    end

    # Nạp bộ loại phòng gợi ý theo loại hình spa.
    def seed_presets
      added = 0
      RoomType.presets_for(current_workspace.business_type).each_with_index do |attrs, i|
        next if current_workspace.room_types.exists?(key: attrs[:key])
        current_workspace.room_types.create!(attrs.merge(position: i))
        added += 1
      end
      redirect_to merchant_room_types_path, notice: "Đã nạp #{added} loại phòng gợi ý."
    end

    private

    def set_room_type = @room_type = current_workspace.room_types.find(params[:id])

    def room_type_params
      params.require(:room_type).permit(:key, :name, :icon, :color, :default_capacity, :position)
    end

    def nav_key = :rooms
  end
end
