threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

if ENV["RAILS_ENV"] == "production"
  # `__FILE__` nằm trong thư mục RELEASE đã được giải symlink, nên không dùng nó
  # để suy ra đường dẫn. Deploy dùng hot restart (USR2): Puma tự re-exec, và nếu
  # nó gắn với đường dẫn release cũ thì sau deploy nó nạp lại CHÍNH CODE CŨ —
  # deploy "thành công" nhưng không có gì thay đổi (đã vấp thật). `directory`
  # trỏ vào symlink `current` để mỗi lần re-exec là chdir sang release mới.
  app_root = ENV.fetch("APP_ROOT", "/var/www/aura")
  shared   = "#{app_root}/shared"

  directory "#{app_root}/current"
  bind       "unix://#{shared}/tmp/sockets/puma.sock"
  pidfile    "#{shared}/tmp/pids/puma.pid"
  state_path "#{shared}/tmp/pids/puma.state"
  stdout_redirect "#{shared}/log/puma.log", "#{shared}/log/puma.log", true

  workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
  # Chạy 1 worker (hoặc 0) thì cluster mode chỉ tốn thêm một tiến trình master
  # mà không được gì — máy chủ đang chật RAM nên để Puma tự chọn single mode.
  preload_app! if ENV.fetch("WEB_CONCURRENCY", 2).to_i > 1
  # Bắt buộc khi hot restart bằng USR2: Puma bỏ môi trường bundler cũ và nạp lại
  # Gemfile của release mới. Thiếu nó, re-exec vẫn dùng bundle của release cũ.
  prune_bundler
else
  port ENV.fetch("PORT", 3013)
  plugin :tmp_restart
end

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
