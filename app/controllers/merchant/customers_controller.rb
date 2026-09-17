module Merchant
  # Hồ sơ khách hàng. Lễ tân tạo được chỉ với tên + SĐT; khi khách tự tải app
  # bằng đúng số đó thì toàn bộ lịch sử đã nằm sẵn ở đây.
  class CustomersController < BaseController
    before_action :set_member, only: [:show, :edit, :update, :destroy, :block, :unblock, :preferences]

    def index
      scope = current_workspace.members.includes(:member_tier, :preferred_staff)
      scope = scope.search(params[:q])
      scope = scope.where(status: params[:status]) if Member::STATUSES.include?(params[:status])
      scope = scope.where(member_tier_id: params[:tier_id]) if params[:tier_id].present?
      scope = scope.birthday_in(Date.current.month) if params[:birthday] == "1"
      @sort = params[:sort].presence || "recent"
      scope = case @sort
              when "spent"  then scope.order(total_spent: :desc)
              when "visits" then scope.order(visits_count: :desc)
              when "name"   then scope.order(:name)
              else scope.newest_first
              end
      @members = scope.limit(200).to_a
      @total   = current_workspace.members.count
      @tiers   = current_workspace.member_tiers.ordered.to_a
      @app_users = current_workspace.members.with_app.count
      @birthday_count = current_workspace.members.birthday_in(Date.current.month).count
    end

    def show
      @tiers = current_workspace.member_tiers.ordered.to_a
      @staff = current_workspace.staff_members.active.therapists.ordered.to_a
    end

    def new
      @member = current_workspace.members.new(source: "walk_in", home_branch_id: current_branch&.id)
      load_options
    end

    def create
      @member = current_workspace.members.new(member_params)
      @member.source = "walk_in" if @member.source.blank?
      if @member.save
        audit!("customer.create", target: @member, summary: @member.display_name)
        redirect_to merchant_customer_path(@member), notice: "Đã tạo hồ sơ khách."
      else
        load_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit = load_options

    def update
      if @member.update(member_params)
        audit!("customer.update", target: @member, summary: @member.display_name)
        redirect_to merchant_customer_path(@member), notice: "Đã lưu hồ sơ khách."
      else
        load_options
        render :edit, status: :unprocessable_entity
      end
    end

    # Sở thích khách (áp lực tay, tinh dầu, giới tính KTV…) — KTV nào cũng đọc được.
    def preferences
      prefs = @member.preferences.dup
      Member::PREFERENCE_FIELDS.each_key do |key|
        val = params.dig(:preferences, key).to_s.strip
        val.present? ? prefs[key] = val : prefs.delete(key)
      end
      @member.update!(preferences: prefs)
      redirect_to merchant_customer_path(@member), notice: "Đã lưu sở thích của khách."
    end

    def block
      @member.update!(status: "blocked", blocked_at: Time.current,
                      blocked_reason: params[:reason].presence)
      audit!("customer.block", target: @member, summary: params[:reason].presence || "—")
      redirect_to merchant_customer_path(@member), notice: "Đã chặn khách này khỏi đặt lịch."
    end

    def unblock
      @member.update!(status: "active", blocked_at: nil, blocked_reason: nil, no_show_count: 0)
      audit!("customer.unblock", target: @member)
      redirect_to merchant_customer_path(@member), notice: "Đã bỏ chặn khách."
    end

    def destroy
      name = @member.display_name
      @member.destroy
      audit!("customer.destroy", summary: name)
      redirect_to merchant_customers_path, notice: "Đã xoá hồ sơ khách."
    end

    private

    def set_member = @member = current_workspace.members.find(params[:id])

    def load_options
      @tiers = current_workspace.member_tiers.ordered.to_a
      @branches = current_workspace.branches.ordered.to_a
      @staff = current_workspace.staff_members.active.therapists.ordered.to_a
    end

    def member_params
      params.require(:member).permit(:phone, :email, :name, :gender, :dob, :address_line, :city,
                                     :member_tier_id, :preferred_staff_id, :home_branch_id, :code,
                                     :source, :health_notes, :notes, :marketing_opt_in, :locale, :avatar)
    end

    def nav_key = :customers
  end
end
