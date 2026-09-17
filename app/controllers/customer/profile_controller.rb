module Customer
  class ProfileController < BaseController
    before_action :require_workspace!
    before_action :require_member!

    def show
      @member = current_member
      @branches = current_workspace.branches.bookable.ordered.to_a
      @staff = current_workspace.staff_members.bookable.at_branch(@member.home_branch_id).ordered.to_a
      @preference_fields = Member::PREFERENCE_FIELDS
      @tier = @member.member_tier
    end

    def update
      @member = current_member
      @member.assign_attributes(profile_params)
      apply_preferences
      if @member.save
        redirect_to member_profile_path, notice: "Đã cập nhật thông tin."
      else
        @branches = current_workspace.branches.bookable.ordered.to_a
        @staff = current_workspace.staff_members.bookable.ordered.to_a
        @preference_fields = Member::PREFERENCE_FIELDS
        @tier = @member.member_tier
        render :show, status: :unprocessable_entity
      end
    end

    private

    # Sở thích khách khai một lần — mọi KTV đọc được, khách không phải nhắc lại
    # "nhẹ tay thôi" ở mỗi lần đến.
    def apply_preferences
      return if params[:preferences].blank?
      prefs = @member.preferences.dup
      Member::PREFERENCE_FIELDS.each_key do |key|
        val = params[:preferences][key].to_s.strip
        val.present? ? prefs[key] = val : prefs.delete(key)
      end
      @member.preferences = prefs
    end

    def profile_params
      params.require(:member).permit(:name, :email, :gender, :dob, :locale,
                                     :home_branch_id, :preferred_staff_id, :health_notes,
                                     :marketing_opt_in, :avatar)
    end
  end
end
