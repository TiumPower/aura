# Nạp lại Puma bằng hot restart (USR2) thay vì systemctl restart.
#
# `systemctl restart` tắt hẳn Puma rồi bật lại — unix socket biến mất ~15 giây
# và nginx trả 502 cho mọi người trong lúc đó (đã gặp thật ở lần deploy đầu).
# USR2 khiến Puma tự re-exec mà GIỮ NGUYÊN socket đang lắng nghe, nên deploy
# không làm rớt kết nối nào.
namespace :puma do
  desc "Hot restart Puma (USR2) — không làm rớt kết nối"
  task :hot_restart do
    on roles(:app) do
      unit = "#{fetch(:application)}_puma_#{fetch(:rails_env)}"
      with xdg_runtime_dir: "/run/user/1000" do
        if test("XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active --quiet #{unit}")
          execute "XDG_RUNTIME_DIR=/run/user/1000 systemctl --user reload #{unit}"
        else
          execute "XDG_RUNTIME_DIR=/run/user/1000 systemctl --user start #{unit}"
        end
      end
    end
  end
end

# Thay nhánh restart mặc định của capistrano3-puma.
Rake::Task["deploy:restart"].clear_actions if Rake::Task.task_defined?("deploy:restart")
namespace :deploy do
  task restart: "puma:hot_restart"
end
