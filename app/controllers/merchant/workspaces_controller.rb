module Merchant
  class WorkspacesController < BaseController
    def switch
      ws = accessible_workspaces.find { |w| w.id == params[:id].to_i }
      if ws
        session[:workspace_id] = ws.id
        session.delete(:branch_id)
      end
      redirect_to merchant_url_for(ws || current_workspace), allow_other_host: true
    end

    # Đổi cơ sở đang xem. Nhân sự bị gán cứng một cơ sở thì không đổi được —
    # phân quyền theo cơ sở nằm ở membership, không ở session.
    def switch_branch
      return redirect_back(fallback_location: merchant_root_path) if current_membership&.branch_id.present?
      id = params[:id].to_s
      if id == "all"
        session.delete(:branch_id)
      elsif (b = current_workspace.branches.find_by(id: id))
        session[:branch_id] = b.id
      end
      redirect_back fallback_location: merchant_root_path
    end
  end
end
