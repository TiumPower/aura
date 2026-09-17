lock "~> 3.18"

set :application, "aura"
set :repo_url,    "git@github.com:vietlee/aura.git"

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
set :puma_threads,        [2, 4]
set :puma_workers,        2
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

  desc "Định vị các toà nhà chưa có toạ độ bản đồ (cap production deploy:geocode)"
  task :geocode do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "aura:geocode_buildings"
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
      line = "15 3 * * * #{dest} >> #{shared_path}/log/backup.log 2>&1"
      # Idempotent: drop any previous aura_backup line, then append ours.
      execute %(crontab -l 2>/dev/null | grep -v 'aura_backup.sh' > /tmp/aura_cron || true)
      execute %(echo "#{line}" >> /tmp/aura_cron && crontab /tmp/aura_cron && rm -f /tmp/aura_cron)
    end
  end
  after :finishing, :install_backup
end
