module Merchant
  class BaseController < ApplicationController
    layout "merchant"

    before_action :require_staff!
    before_action :no_browser_cache
    before_action :set_current_workspace
    before_action :require_accessible_workspace
    before_action :enforce_workspace_access
    around_action :scope_tenant

    helper_method :current_workspace, :accessible_workspaces, :current_membership,
                  :nav_key, :feature_locked?, :impersonating?,
                  :current_branch, :branch_options, :chat_unread_count,
                  :module_on?

    # Nhân sự đăng nhập bằng luồng riêng (không dùng route session của Devise),
    # nên khách chưa đăng nhập phải về cổng nhân sự — không đẩy sang app khách.
    def require_staff!
      return if user_signed_in?
      redirect_to merchant_login_path, alert: "Vui lòng đăng nhập tài khoản quản lý."
    end

    def impersonating? = session[:impersonator_admin_id].present?

    def chat_unread_count
      return 0 unless current_workspace
      @chat_unread_count ||= current_workspace.conversations.where("staff_unread > 0").sum(:staff_unread)
    end

    # Tính năng bị KHOÁ vì gói thuê bao (bản dùng thử mở hết).
    def feature_locked?(feature) = current_workspace && !current_workspace.plan_allows?(feature)

    # Module spa đã bật hay chưa (gói cho phép + spa bật).
    def module_on?(key) = current_workspace&.feature?(key)

    private

    def accessible_workspaces
      @accessible_workspaces ||= current_user ? current_user.workspaces.order(:created_at).to_a : []
    end

    def current_workspace = @current_workspace

    def set_current_workspace
      return unless current_user
      host_ws = workspace_from_host
      if host_ws && accessible_workspaces.any? { |w| w.id == host_ws.id }
        @current_workspace = host_ws
      elsif session[:workspace_id].present?
        @current_workspace = accessible_workspaces.find { |w| w.id == session[:workspace_id].to_i }
      end
      @current_workspace ||= accessible_workspaces.first
      session[:workspace_id] = @current_workspace&.id
    end

    # Cơ sở đang xem. Nhân sự bị gán cứng một cơ sở thì KHÔNG đổi được — phân
    # quyền theo cơ sở nằm ở membership.branch_id, không nằm ở session.
    def current_branch
      return @current_branch if defined?(@current_branch)
      @current_branch = begin
        next_branch = nil
        if current_membership&.branch_id.present?
          next_branch = branch_scope.find_by(id: current_membership.branch_id)
        else
          requested = params[:branch_id].presence || session[:branch_id]
          next_branch = branch_scope.find_by(id: requested) if requested.present?
        end
        next_branch
      end
    end

    def branch_scope = current_workspace ? current_workspace.branches : Branch.none

    def branch_options
      @branch_options ||= begin
        scope = branch_scope.where.not(status: "archived").ordered.to_a
        if current_membership&.branch_id.present?
          scope.select { |b| b.id == current_membership.branch_id }
        else
          scope
        end
      end
    end

    # Lọc một quan hệ theo cơ sở đang xem (không chọn cơ sở = xem tất cả).
    def by_branch(relation, column = :branch_id)
      current_branch ? relation.where(column => current_branch.id) : relation
    end

    def require_accessible_workspace
      return if @current_workspace
      sign_out(current_user)
      redirect_to merchant_login_path,
        alert: "Tài khoản này chưa thuộc spa nào. Vui lòng đăng nhập lại."
    end

    def workspace_from_host
      sub = request.subdomains.first
      unless sub.blank? || TenantResolver::RESERVED_SUBDOMAINS.include?(sub)
        ws = Workspace.find_by(subdomain: sub)
      end
      ws || Workspace.find_by(custom_domain: request.host)
    end

    def scope_tenant
      if @current_workspace
        ActsAsTenant.with_tenant(@current_workspace) { yield }
      else
        yield
      end
    end

    def enforce_workspace_access
      return unless @current_workspace
      @block_reason = @current_workspace.access_blocked_reason
      return unless @block_reason
      return if @block_reason == :unpaid && %w[billing subscription].include?(controller_name)
      render "merchant/shared/locked", layout: "auth", status: :forbidden
    end

    def current_membership
      return nil unless current_user && current_workspace
      @current_membership ||= current_user.membership_for(current_workspace)
    end

    def require_manager!
      return if current_membership&.can_manage?
      redirect_to merchant_root_path, alert: "Chỉ chủ spa / quản lý mới có quyền."
    end

    def require_front_desk!
      return if current_membership&.front_desk?
      redirect_to merchant_root_path, alert: "Thao tác này dành cho quầy lễ tân."
    end

    # Ghi nhật ký thao tác. Gọi ở mọi chỗ ghi dữ liệu có tranh chấp.
    def audit!(action, target: nil, summary: nil, payload: {})
      AuditLog.record!(workspace: current_workspace, actor: current_user, action: action,
                       target: target, summary: summary, payload: payload, ip: request.remote_ip)
    end

    def nav_key = nil
  end
end
