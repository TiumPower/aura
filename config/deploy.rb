lock "~> 3.18"

set :application, "aura"
# Repo bare NGAY TRÊN SERVER (như BƠI ĐẠT): máy này không có `gh` CLI và
# ssh-agent không giữ khoá GitHub, nên clone qua agent forwarding sẽ thất bại.
# Đẩy code: `git push production main` rồi `cap production deploy`.
set :repo_url,    ENV.fetch("REPO_URL", "/home/deploy/repos/aura.git")

set :deploy_to,   "/var/www/aura"
set :branch,      ENV.fetch("BRANCH", "main")

# rbenv
set :rbenv_type,   :user
set :rbenv_ruby,   File.read(".ruby-version").strip.sub(/^ruby-/, "")
set :rbenv_prefix, "RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=#{fetch(:rbenv_ruby)} $HOME/.rbenv/bin/rbenv exec"
set :rbenv_path,   "$HOME/.rbenv"

# Shared files/dirs persisted across deploys
set :linked_files, %w[.env]
set :linked_dirs, %w[
  log
  tmp/pids
  tmp/cache
  tmp/sockets
  storage
  public/assets
]

set :keep_releases, 5
set :assets_roles, [:web]

# Puma
# Máy chủ đang chạy 5 ứng dụng Rails trên 3.7GB RAM. Aura dùng MỘT worker
# (~200MB) thay vì hai — thêm worker thứ hai là đẩy cả máy vào swap.
set :puma_threads,        [2, 5]
set :puma_workers,        1
set :puma_bind,           "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,          "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,            "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log,     "#{release_path}/log/puma.access.log"
set :puma_error_log,      "#{release_path}/log/puma.error.log"
set :puma_preload_app,    true
set :puma_init_active_record, true

# Sidekiq (systemd)
set :sidekiq_config, "#{current_path}/config/sidekiq.yml"

namespace :deploy do
  desc "XOÁ toàn bộ spa rồi dựng lại bộ dữ liệu test (cap production deploy:test_data PASSWORD=...)"
  task :test_data do
    pw = ENV["PASSWORD"].to_s
    raise "Cần PASSWORD='<mật khẩu ≥12 ký tự>'" if pw.length < 12
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env), password: pw, confirm: "yes" do
          execute :rake, "aura:test_data"
        end
      end
    end
  end

  desc "Seed database (run manually: cap production deploy:seed)"
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed"
        end
      end
    end
  end

  desc "Chép tệp Active Storage từ đĩa lên DigitalOcean Spaces (cap production deploy:to_spaces)"
  task :to_spaces do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "storage:to_spaces"
        end
      end
    end
  end

  desc "Kiểm tra mọi tệp đính kèm đọc được (cap production deploy:verify_storage)"
  task :verify_storage do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "storage:verify"
        end
      end
    end
  end

  after :publishing, :restart

  after :finishing, :restart_sidekiq do
    on roles(:app) do
      execute :sudo, "systemctl restart sidekiq-aura"
    end
  end

  # Keep the nightly backup script in shared/ rather than in the release: a bad
  # deploy (or a rolled-back release) must never be able to stop backups. The
  # source of truth stays in the repo, copied out on every deploy.
  desc "Install the nightly backup script and its cron entry"
  task :install_backup do
    on roles(:db) do
      dest = "#{shared_path}/bin/aura_backup.sh"
      execute :mkdir, "-p", "#{shared_path}/bin"
      upload! "bin/aura_backup.sh", dest
      execute :chmod, "+x", dest
      # 4:15 — KHÔNG trùng estate (3:15) và loyalty (3:45): cả ba dùng chung một
      # máy 3.7GB RAM, chạy đồng thời hai pg_dump + tar là đẩy máy vào swap.
      line = "15 4 * * * #{dest} >> #{shared_path}/log/backup.log 2>&1"
      # Idempotent: drop any previous aura_backup line, then append ours.
      execute %(crontab -l 2>/dev/null | grep -v 'aura_backup.sh' > /tmp/aura_cron || true)
      execute %(echo "#{line}" >> /tmp/aura_cron && crontab /tmp/aura_cron && rm -f /tmp/aura_cron)
    end
  end
  after :finishing, :install_backup
end
