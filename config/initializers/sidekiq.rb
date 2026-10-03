require "sidekiq"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  # Dọn dẹp định kỳ qua sidekiq-cron.
  #
  # Danh sách này từng được copy nguyên từ app quản lý căn hộ và lên lịch bốn
  # class KHÔNG hề tồn tại ở đây (BillCycleJob, BillRemindersJob,
  # LeaseExpiryJob, và cả MaintenanceJob) — mỗi lần cron chạy là một NameError
  # im lặng trong Sidekiq. Chỉ giữ những job app này thật sự có.
  config.on(:startup) do
    schedule = {
      "daily_maintenance"    => { "cron" => "0 3 * * *", "class" => "MaintenanceJob", "queue" => "default" },
      "daily_billing_renewal" => { "cron" => "30 3 * * *", "class" => "BillingRenewalJob", "queue" => "default" },
      "deliver_scheduled_broadcasts" => { "cron" => "*/5 * * * *", "class" => "BroadcastDeliveryJob", "queue" => "default" }
    }
    if defined?(Sidekiq::Cron::Job)
      Sidekiq::Cron::Job.load_from_hash(schedule)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
