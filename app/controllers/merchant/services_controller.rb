module Merchant
  # Danh mục dịch vụ. Đây là bản ghi engine xếp lịch đọc, nên mấy trường "khô
  # khan" (thời lượng, loại phòng, cần mấy KTV) quan trọng hơn cả mô tả.
  class ServicesController < BaseController
    before_action :require_manager!, except: [:index, :show]
    before_action :set_service, only: [:show, :edit, :update, :destroy, :archive]

    def index
      scope = current_workspace.services.includes(:service_category, :service_variants)
      scope = scope.in_category(params[:category_id])
      scope = params[:addons] == "1" ? scope.where(is_addon: true) : scope.where(is_addon: false)
      @status = params[:status].presence || "active"
      scope = scope.where(active: @status == "active") if %w[active inactive].include?(@status)
      @services = scope.ordered.to_a
      @categories = current_workspace.service_categories.ordered.to_a
      @counts = {
        active: current_workspace.services.main.active.count,
        addons: current_workspace.services.where(is_addon: true).count,
        inactive: current_workspace.services.where(active: false).count
      }
    end

    def show
      @variants = @service.service_variants.ordered.to_a
      @new_variant = @service.service_variants.new
      @staff = current_workspace.staff_members.active.therapists.ordered.to_a
      @skilled_ids = @service.staff_services.pluck(:staff_member_id)
      @branches = current_workspace.branches.ordered.to_a
      @room_types = current_workspace.room_types.ordered.to_a
    end

    def new
      @service = current_workspace.services.new(
        duration_minutes: 60, price: 0, active: true, online_bookable: true,
        is_addon: params[:addon] == "1", requires_room: true, requires_staff: true, staff_count: 1
      )
      load_options
    end

    def create
      @service = current_workspace.services.new(service_params)
      if @service.save
        audit!("service.create", target: @service, summary: @service.name)
        redirect_to merchant_service_path(@service), notice: "Đã thêm dịch vụ."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit = load_options

    def update
      if @service.update(service_params)
        audit!("service.update", target: @service, summary: @service.name)
        redirect_to merchant_service_path(@service), notice: "Đã lưu dịch vụ."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    # Ngưng bán nhưng giữ lịch sử — dịch vụ đã từng bán thì không xoá.
    def archive
      @service.update!(active: false, online_bookable: false)
      audit!("service.archive", target: @service, summary: @service.name)
      redirect_to merchant_services_path, notice: "Đã ngưng bán #{@service.name}."
    end

    def destroy
      if @service.booking_items.exists?
        return redirect_to merchant_service_path(@service),
          alert: "Dịch vụ này đã có lịch hẹn — hãy ngưng bán thay vì xoá."
      end
      name = @service.name
      @service.destroy
      audit!("service.destroy", summary: name)
      redirect_to merchant_services_path, notice: "Đã xoá dịch vụ."
    end

    private

    def set_service = @service = current_workspace.services.friendly.find(params[:id])

    def load_options
      @categories = current_workspace.service_categories.ordered.to_a
      @room_types = current_workspace.room_types.ordered.to_a
    end

    def service_params
      permitted = params.require(:service).permit(
        :service_category_id, :name, :code, :description, :prep_notes, :contraindications,
        :duration_minutes, :buffer_minutes, :price, :cost,
        :requires_room, :requires_staff, :staff_count, :is_addon,
        :online_bookable, :active, :deposit_required, :deposit_amount,
        :commission_percent, :points_earned, :position, :photo,
        room_type_ids: []
      )
      permitted[:room_type_ids] = Array(permitted[:room_type_ids]).reject(&:blank?).map(&:to_i)
      permitted
    end

    def nav_key = :services
  end
end
