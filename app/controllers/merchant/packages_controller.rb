module Merchant
  # Định nghĩa gói/thẻ để bán: thẻ liệu trình n buổi, thẻ tiền, thẻ thành viên.
  class PackagesController < BaseController
    before_action :require_manager!
    before_action :check_module!
    before_action :set_package, only: [:show, :edit, :update, :destroy, :archive]

    def index
      @packages = current_workspace.packages.includes(package_lines: :service).ordered.to_a
      @sold = MemberPackage.where(package_id: @packages.map(&:id)).group(:package_id).count
      @revenue = MemberPackage.where(package_id: @packages.map(&:id)).group(:package_id).sum(:price_paid)
    end

    def show
      @cards = current_workspace.member_packages.where(package_id: @package.id)
                                .includes(:member).recent.limit(50).to_a
    end

    def new
      @package = current_workspace.packages.new(kind: "session_pack", active: true)
      @package.package_lines.build
      load_options
    end

    def create
      @package = current_workspace.packages.new(package_params)
      if @package.save
        audit!("package.create", target: @package, summary: @package.name)
        redirect_to merchant_package_path(@package), notice: "Đã tạo gói."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @package.package_lines.build if @package.package_lines.empty?
      load_options
    end

    def update
      if @package.update(package_params)
        audit!("package.update", target: @package, summary: @package.name)
        redirect_to merchant_package_path(@package), notice: "Đã lưu gói."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      @package.update!(active: false, online_sellable: false)
      redirect_to merchant_packages_path, notice: "Đã ngưng bán #{@package.name}."
    end

    def destroy
      if MemberPackage.exists?(package_id: @package.id)
        return redirect_to merchant_package_path(@package),
          alert: "Gói này đã bán cho khách — hãy ngưng bán thay vì xoá."
      end
      name = @package.name
      @package.destroy
      redirect_to merchant_packages_path, notice: "Đã xoá gói #{name}."
    end

    private

    def check_module!
      return if current_workspace.feature?("packages")
      redirect_to merchant_root_path, alert: "Module thẻ liệu trình đang tắt (xem Thiết lập → Module)."
    end

    def set_package = @package = current_workspace.packages.find(params[:id])

    def load_options
      @services = current_workspace.services.main.active.ordered.to_a
    end

    def package_params
      params.require(:package).permit(
        :name, :kind, :description, :price, :face_value, :validity_days,
        :transferable, :family_share, :online_sellable, :active,
        :commission_percent, :position,
        package_lines_attributes: [:id, :service_id, :service_variant_id, :sessions, :_destroy]
      )
    end

    def nav_key = :packages
  end
end
