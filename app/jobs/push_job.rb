class PushJob < ApplicationJob
  queue_as :default

  def perform(workspace_id, member_ids, title, body, path = "/")
    ws = Workspace.find_by(id: workspace_id) or return
    ActsAsTenant.with_tenant(ws) do
      PushSender.deliver_to(Array(member_ids), title: title, body: body, path: path)
    end
  end
end
