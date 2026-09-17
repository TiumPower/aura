# Thiết lập mặc định cho một workspace vừa tạo. Cơ sở / phòng / KTV do chủ spa
# khai trong bước onboarding, nên ở đây chỉ đóng dấu các mốc cần cho dashboard
# render được và chọn sẵn bộ module theo loại hình.
module WorkspaceBootstrap
  module_function

  def call(workspace)
    ActsAsTenant.with_tenant(workspace) do
      workspace.update!(settings: workspace.settings.reverse_merge(
        "onboarded" => false,
        "modules"   => BusinessSettings::MODULE_PRESETS[workspace.business_type] ||
                       BusinessSettings::MODULE_PRESETS["mixed"]
      ))
    end
    workspace
  end
end
