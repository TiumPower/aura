module Merchant
  # Gửi thông báo (in-app + push) tới nhóm khách đã chọn: tất cả, theo hạng thẻ,
  # theo cơ sở thường đến, khách có sinh nhật tháng này, hoặc khách đã lâu không
  # tới (nhóm cần kéo về nhất của một spa).
  class AnnouncementsController < BaseController
    SEGMENTS = [
      ["Tất cả khách đang hoạt động", "all"],
      ["Khách đã cài app (nhận được push)", "app"],
      ["Theo hạng thẻ", "tier"],
      ["Theo cơ sở thường đến", "branch"],
      ["Sinh nhật tháng này", "birthday"],
      ["Lâu chưa quay lại (>60 ngày)", "lapsed"]
    ].freeze

    def new
      load_form
    end

    def create
      title = params[:title].to_s.strip
      body  = params[:body].to_s.strip
      return reject("Vui lòng nhập tiêu đề và nội dung.") if title.blank? || body.blank?

      members = target_members.to_a
      return reject("Không có khách nào trong nhóm đã chọn.") if members.empty?

      broadcast = current_workspace.broadcasts.create!(
        title: title, body: body, segment_key: params[:segment].to_s.presence || "all",
        created_by: current_user
      )
      broadcast.deliver!(members)
      audit!("announcement.send", target: broadcast, summary: "#{members.size} khách · #{title}")
      redirect_to merchant_new_announcement_path, notice: "Đã gửi thông báo tới #{members.size} khách."
    end

    private

    def load_form
      @segments = SEGMENTS
      @tiers    = current_workspace.member_tiers.ordered.to_a
      @branches = current_workspace.branches.ordered.to_a
      @counts = {
        "all"      => current_workspace.members.active.count,
        "app"      => current_workspace.members.active.with_app.count,
        "birthday" => current_workspace.members.active.birthday_in(Date.current.month).count,
        "lapsed"   => lapsed_scope.count
      }
      @recent = current_workspace.broadcasts.recent.limit(10).to_a
    end

    def lapsed_scope
      current_workspace.members.active
        .where("last_visit_at IS NULL OR last_visit_at < ?", 60.days.ago)
    end

    def reject(message)
      flash.now[:alert] = message
      load_form
      render :new, status: :unprocessable_entity
    end

    def target_members
      base = current_workspace.members.active
      case params[:segment]
      when "app"      then base.with_app
      when "tier"     then base.where(member_tier_id: Array(params[:tier_ids]).map(&:to_i))
      when "branch"   then base.where(home_branch_id: Array(params[:branch_ids]).map(&:to_i))
      when "birthday" then base.birthday_in(Date.current.month)
      when "lapsed"   then lapsed_scope
      else base
      end
    end

    def nav_key = :announcements
  end
end
