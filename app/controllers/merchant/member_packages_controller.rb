module Merchant
  # Thẻ khách đã mua: xem còn mấy buổi, tạm dừng, gia hạn, tặng thêm buổi.
  class MemberPackagesController < BaseController
    before_action :set_card, only: [:show, :freeze, :unfreeze, :grant, :extend_expiry]

    def index
      scope = current_workspace.member_packages.includes(:member, :package, :package_credits)
      @status = params[:status].presence || "active"
      scope = scope.where(status: @status) if MemberPackage::STATUSES.include?(@status)
      scope = scope.joins(:member).merge(Member.search(params[:q])) if params[:q].present?
      @cards = scope.recent.limit(200).to_a
      @counts = current_workspace.member_packages.group(:status).count
      @expiring = current_workspace.member_packages.expiring_within(
        current_workspace.setting_i("package_expiry_warning_days")).includes(:member).to_a
      @low = current_workspace.member_packages.usable.includes(:package_credits).select(&:low_on_sessions?)
    end

    def show
      @uses = PackageCreditUse.where(package_credit_id: @card.package_credits.map(&:id))
                              .recent.limit(60).to_a
    end

    # Lễ tân bán thẻ ngoài luồng bill (hiếm, nhưng có: khách chuyển khoản trước).
    def create
      return redirect_to(merchant_member_packages_path, alert: "Chỉ quản lý mới tạo thẻ tay.") unless current_membership&.can_manage?
      member = current_workspace.members.find(params[:member_id])
      pkg = current_workspace.packages.find(params[:package_id])
      card = nil
      MemberPackage.transaction do
        card = member.member_packages.create!(
          workspace: current_workspace, package: pkg, name: pkg.name, kind: pkg.kind,
          price_paid: params[:price_paid].presence&.to_i || pkg.price,
          value_balance: pkg.value_card? ? pkg.face : 0,
          purchased_on: Date.current,
          expires_on: pkg.validity.positive? ? Date.current + pkg.validity.days : nil,
          note: "Tạo tay bởi #{current_user.name}"
        )
        pkg.package_lines.each do |line|
          card.package_credits.create!(workspace: current_workspace, service: line.service,
                                       service_variant: line.service_variant,
                                       total_sessions: line.sessions)
        end
      end
      audit!("card.create", target: card, summary: "#{member.display_name} · #{pkg.name}")
      redirect_to merchant_member_package_path(card), notice: "Đã tạo thẻ cho khách."
    end

    def freeze
      @card.update!(status: "frozen", frozen_at: Time.current)
      audit!("card.freeze", target: @card, summary: @card.name)
      redirect_to merchant_member_package_path(@card), notice: "Đã tạm dừng thẻ."
    end

    def unfreeze
      @card.update!(status: "active", frozen_at: nil)
      redirect_to merchant_member_package_path(@card), notice: "Đã mở lại thẻ."
    end

    # Tặng thêm buổi (đền bù, khuyến mãi). Ghi nhật ký vì đây là "cho tiền".
    def grant
      return redirect_to(merchant_member_package_path(@card), alert: "Chỉ quản lý mới tặng buổi.") unless current_membership&.can_manage?
      credit = @card.package_credits.find(params[:credit_id])
      n = params[:sessions].to_i
      return redirect_to(merchant_member_package_path(@card), alert: "Số buổi không hợp lệ.") if n <= 0
      credit.update!(total_sessions: credit.total_sessions + n)
      credit.package_credit_uses.create!(workspace: current_workspace, sessions: -n,
                                         reason: params[:reason].presence || "Tặng buổi",
                                         actor_id: current_user.id, used_at: Time.current)
      @card.update!(status: "active") if @card.status == "used_up"
      audit!("card.grant", target: @card, summary: "+#{n} buổi #{credit.service.name} · #{params[:reason]}")
      redirect_to merchant_member_package_path(@card), notice: "Đã tặng #{n} buổi."
    end

    def extend_expiry
      return redirect_to(merchant_member_package_path(@card), alert: "Chỉ quản lý mới gia hạn thẻ.") unless current_membership&.can_manage?
      days = params[:days].to_i
      base = @card.expires_on || Date.current
      @card.update!(expires_on: base + days.days, status: @card.status == "expired" ? "active" : @card.status)
      audit!("card.extend", target: @card, summary: "+#{days} ngày → #{@card.expires_on}")
      redirect_to merchant_member_package_path(@card), notice: "Đã gia hạn thêm #{days} ngày."
    end

    private

    def set_card
      @card = current_workspace.member_packages.includes(:member, :package, package_credits: :service)
                               .find(params[:id])
    end

    def nav_key = :packages
  end
end
