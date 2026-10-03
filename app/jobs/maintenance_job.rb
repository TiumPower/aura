class MaintenanceJob < ApplicationJob
  queue_as :default

  def perform
    result = Maintenance.run_all
    Rails.logger.info("[MaintenanceJob] #{result.inspect}")
  end
end
