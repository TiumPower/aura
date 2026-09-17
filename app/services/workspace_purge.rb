# Xoá hẳn một workspace và mọi dòng thuộc nó. Mọi bảng nghiệp vụ đều có
# workspace_id nên xoá theo cột đó, theo thứ tự an toàn khoá ngoại (con trước
# cha) thay vì trông vào cascade của ActiveRecord.
class WorkspacePurge
  # Thứ tự quan trọng: bảng nào tham chiếu bảng khác thì phải nằm TRƯỚC bảng đó.
  DELETE_ORDER = %w[
    audit_logs messages conversations notifications push_subscriptions broadcasts
    staff_shifts shift_templates staff_branches
    expenses
    members member_tiers
    rooms room_types
    staff_members staff_levels
    branch_hours branch_closures branches
    memberships invoices otp_challenges
  ].freeze

  def self.call(workspace)
    ActsAsTenant.without_tenant do
      ApplicationRecord.transaction do
        wid = workspace.id
        purge_attachments("Workspace", [wid])
        %w[Member StaffMember Branch].each do |klass|
          ids = klass.constantize.where(workspace_id: wid).pluck(:id)
          purge_attachments(klass, ids) if ids.any?
        end

        conn = ApplicationRecord.connection
        DELETE_ORDER.each do |table|
          conn.exec_delete("DELETE FROM #{table} WHERE workspace_id = #{wid.to_i}", "WorkspacePurge")
        end
        workspace.destroy!
      end
    end
    true
  end

  def self.purge_attachments(record_type, ids)
    ActiveStorage::Attachment.where(record_type: record_type, record_id: ids).find_each do |att|
      att.purge
    rescue => e
      Rails.logger.error("[WorkspacePurge] attachment #{att.id}: #{e.class} #{e.message}")
    end
  end
end
