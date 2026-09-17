# Aura — Quản lý căn hộ cho thuê

Nền tảng SaaS đa workspace (multi-tenant) giúp chủ hộ quản lý toà nhà, căn hộ, hợp đồng,
điện nước, thu chi và người thuê. Mỗi chủ hộ có **subdomain riêng** cho trang quản lý và
PWA của người thuê. Xây trên nền tảng dùng chung với Loyalty (Rails 7.2 + Postgres +
Tailwind + Devise + acts_as_tenant + Hotwire + PWA).

## 3 site
- **Super Admin** (`/admin`) — quản lý chủ hộ (workspace), gói thuê bao, giám sát.
- **Chủ hộ / Landlord** (`/merchant`) — đăng nhập email + OTP, tạo toà nhà & căn hộ, chia sẻ link/QR.
- **Người thuê / Tenant PWA** (subdomain hoặc `/w/:slug`) — đăng nhập email + OTP, thông báo, hồ sơ.

## Chạy dev
```bash
bin/rails db:create db:migrate db:seed
bin/rails server -p 3010
```

### Tài khoản demo (sau khi seed)
- Super Admin: `/admin/login` — `admin@aura.local` / `password`
- Chủ hộ: `/merchant/login` — email `chuho@aura.local` (mã OTP hiển thị trên màn hình ở dev)
- Người thuê: `/w/sunrise-apartments/login` (email bất kỳ, OTP hiển thị trên màn hình)

Mail gửi chung từ `Dynamic aura <no-reply@czin.net>`.

## Trạng thái: Phase 0 ✅
Nền multi-workspace + auth email/OTP + onboarding tạo toà + quản lý toà/căn + link/QR chia sẻ +
trang public listing + landing marketing + super admin (workspace/gói/giám sát).

Roadmap: P1 listing nâng cao · P2 hợp đồng & cọc · P3 hoá đơn + AI đọc công tơ + VietQR ·
P4 thanh toán PWA · P5 maintenance + chat · P6 báo cáo + tạm trú + trợ lý AI.
