# Aura — hạ tầng production

Live: **https://aura.tiumpower.com** (apex: `/admin`, `/merchant`) và
`https://<subdomain>.aura.tiumpower.com` (app khách, white-label theo từng spa).

## Máy chủ

`103.116.38.152` (Ubuntu 24.04, 4 vCPU / 3.7GB / 40GB), user `deploy` với sudo
NOPASSWD. **Dùng chung với loyalty, estate, boidat, xstudio, machai** — mọi
quyết định về cấu hình đều phải tính tới bốn app kia.

| Tài nguyên | Aura dùng |
|---|---|
| Thư mục | `/var/www/aura` |
| Postgres | role `aura`, db `aura_production` (mật khẩu trong `shared/.env`) |
| Redis | database **6** (loyalty 2, estate 3, boidat 4, xstudio 5) |
| Puma | systemd **user** unit `aura_puma_production`, single mode, unix socket |
| Sidekiq | system unit `sidekiq-aura`, concurrency 3 |
| nginx | `/etc/nginx/sites-available/aura.tiumpower.com` (bản gốc ở `config/nginx/`) |
| TLS | cert `aura-wildcard` (`*.aura.tiumpower.com` + apex), DNS-01 qua Cloudflare, tự gia hạn |
| Sao lưu | cron 4:15 hằng ngày → `/var/www/aura/backups` (30 ngày) |
| Tệp tải lên | DigitalOcean Spaces, bucket `czin`, tiền tố `aura/`, mirror xuống đĩa |

## Deploy

```bash
git push origin main
bundle exec cap production deploy
```

Mã nguồn ở **GitHub** `git@github.com:vietlee/aura.git`; server kéo về qua
**agent forwarding** (`forward_agent: true`), giống loyalty/estate/xstudio.

> Repo bare cũ `/home/deploy/repos/aura.git` (remote `production`) vẫn còn
> nhưng **không còn là nguồn deploy** và không tự đồng bộ với GitHub. Chỉ dùng
> khi GitHub không với tới được:
> `git push production main && REPO_URL=/home/deploy/repos/aura.git bundle exec cap production deploy`.

Deploy dùng **hot restart USR2** nên không gián đoạn (đo được 30/30 request đều
200 xuyên suốt một lần deploy). Điều kiện để hot restart nạp đúng code mới:
`directory "#{APP_ROOT}/current"` + `prune_bundler` trong `config/puma.rb` —
xem phần "Bẫy khi deploy" trong `CLAUDE.md`.

## Bộ nhớ

Máy đã dùng ~2.8/3.7GB và swap ~1.6/2GB với năm app Rails. Aura cố tình chạy
single mode (~180MB) thay vì 2 worker (~400MB). **Trước khi bán cho khách trả
tiền thật, nên tách Aura sang máy riêng hoặc nâng RAM** — thêm một app nữa vào
máy này là chắc chắn swap nặng.

## Việc hạ tầng còn thiếu

- **Cổng gửi SMS/Zalo ZNS cho OTP của khách.** Hiện mã hiện trực tiếp trên màn
  hình (`SHOW_CUSTOMER_OTP=true`) — chỉ dùng được cho demo, PHẢI tắt trước khi
  có khách thật. Khách đã khai email thì OTP đã đi bằng email.
- Bản sao lưu vẫn nằm trên cùng ổ đĩa với database — chưa đẩy ra ngoài máy.
- Chưa diễn tập phục hồi từ bản sao lưu.
- Ruby 3.2.2 và Rails 7.2 đều đã hết hạn hỗ trợ bảo mật (giống bốn app kia).
