module Merchant
  # Thiết lập lần đầu: loại hình spa → cơ sở đầu tiên → bộ loại phòng/hạng KTV/
  # hạng thẻ gợi ý. Xong bước này là spa đã xếp được lịch, không phải mò từng
  # màn hình thiết lập.
  class OnboardingController < BaseController
    STEPS = %w[business branch presets].freeze

    def show
      @workspace = current_workspace
      @step   = STEPS.include?(params[:step]) ? params[:step] : current_step
      @branch = current_workspace.branches.first || current_workspace.branches.new
    end

    def update
      @workspace = current_workspace
      case params[:step]
      when "business" then save_business
      when "branch"   then save_branch
      when "presets"  then save_presets
      else redirect_to merchant_onboarding_path
      end
    end

    def skip
      finish!
    end

    private

    def nav_key = nil

    def current_step
      return "business" unless current_workspace.settings["business_chosen"]
      return "branch" if current_workspace.branches.empty?
      "presets"
    end

    def save_business
      type = Workspace::BUSINESS_TYPES.include?(params[:business_type]) ? params[:business_type] : "massage"
      current_workspace.update!(business_type: type,
                                settings: current_workspace.settings.merge("business_chosen" => true))
      current_workspace.update_modules!(BusinessSettings::MODULE_PRESETS[type])
      redirect_to merchant_onboarding_path(step: "branch")
    end

    def save_branch
      @branch = current_workspace.branches.first || current_workspace.branches.new
      @branch.assign_attributes(branch_params)
      if @branch.save
        @branch.ensure_hours!
        redirect_to merchant_onboarding_path(step: "presets")
      else
        @step = "branch"
        render :show, status: :unprocessable_entity
      end
    end

    # Nạp bộ dữ liệu mẫu để spa có cái mà bấm ngay: loại phòng, hạng KTV,
    # hạng thẻ thành viên. Spa sửa lại sau, nhưng không bắt đầu từ màn trắng.
    def save_presets
      ws = current_workspace
      if params[:seed] != "0"
        seed_room_types(ws)
        seed_staff_levels(ws)
        seed_tiers(ws)
      end
      finish!
    end

    def seed_room_types(ws)
      RoomType.presets_for(ws.business_type).each_with_index do |attrs, i|
        next if ws.room_types.exists?(key: attrs[:key])
        ws.room_types.create!(attrs.merge(position: i))
      end
    end

    def seed_staff_levels(ws)
      StaffLevel::PRESETS.each do |attrs|
        next if ws.staff_levels.exists?(key: attrs[:key])
        ws.staff_levels.create!(attrs)
      end
    end

    def seed_tiers(ws)
      MemberTier::PRESETS.each do |attrs|
        next if ws.member_tiers.exists?(key: attrs[:key])
        ws.member_tiers.create!(attrs)
      end
    end

    def finish!
      ws = current_workspace
      ws.ensure_default_branch!
      ws.update!(settings: ws.settings.merge("onboarded" => true))
      redirect_to merchant_root_path, notice: "Thiết lập xong! Chào mừng đến với Aura 🌿"
    end

    def branch_params
      params.require(:branch).permit(:name, :code, :phone, :address_line, :ward, :district, :city)
    end
  end
end
