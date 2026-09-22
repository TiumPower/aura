# Aura — phần mềm quản lý spa & massage đa cơ sở

Sản phẩm SaaS multi-tenant: mỗi spa là một workspace riêng, có subdomain riêng
(`tenspa.aura.tiumpower.com`), tuỳ chọn tên miền riêng, bộ màu/phông riêng, bộ module
riêng và bộ tham số nghiệp vụ riêng. Cùng một bộ mã chạy cho một tiệm foot
massage một cơ sở và một chuỗi thẩm mỹ viện nhiều cơ sở.

Rails 7.2 · Postgres · Hotwire (Turbo + Stimulus) · Tailwind 4 · Sidekiq · PWA.

## Ba cổng

| Cổng | Đường dẫn | Ai dùng |
|---|---|---|
| Quản lý spa | `/merchant` | Chủ spa, quản lý, lễ tân, kế toán |
| App khách (PWA) | `/` trên subdomain của spa, hoặc `/w/:slug` | Khách hàng |
| Super Admin | `/admin` | Vận hành nền tảng (bán sản phẩm) |

## Lõi nghiệp vụ

```
Workspace (một thương hiệu spa)
├── Branch (cơ sở) ── BranchHour (giờ mở cửa theo thứ) ── BranchClosure (nghỉ lễ)
│   └── Room (phòng/giường, capacity = số chỗ phục vụ ĐỒNG THỜI)
├── StaffMember (KTV/lễ tân/tư vấn) ── StaffShift (ca thật) ← ShiftTemplate (mẫu tuần)
├── Service ── ServiceVariant (60′/90′/120′) ── StaffService (kỹ năng)
├── Member (khách: SĐT là khoá hồ sơ) ── MemberTier (hạng thẻ)
├── Booking ── BookingItem (một lượt chiếm một phòng + một KTV)
├── Order (bill spa thu của khách) ── OrderItem ── OrderPayment
├── Package → MemberPackage → PackageCredit → PackageCreditUse (dấu từng lần trừ)
├── WalletTransaction · PointTransaction · CommissionEntry
└── Invoice (hoá đơn THUÊ BAO nền tảng thu của spa — đừng lẫn với Order)
```

### Ba service giữ toàn bộ luật

- **`SlotFinder`** — nơi duy nhất trả lời "còn nhận khách được không". Một slot
  hợp lệ khi ĐỒNG THỜI: trong giờ mở cửa (đã trừ ngày nghỉ), còn phòng đúng loại
  (tính cả thời gian dọn phòng của lượt trước), đủ KTV đang trong ca và không
  nghỉ phép, không bị chỗ giữ tạm chiếm, và thoả thời gian đặt trước tối thiểu.
- **`BookingScheduler`** — nơi duy nhất tạo/đổi lịch. Kiểm tra trùng chạy lại
  trong transaction trước khi ghi.
- **`Checkout`** — nơi duy nhất thay đổi tiền. Buổi trong thẻ, điểm thưởng và
  hoa hồng chỉ được chốt khi ĐÓNG BILL.

### Cấu hình theo từng tenant

- `workspaces.business_type` (massage / beauty / mixed) quyết định bộ module bật
  sẵn và danh mục gợi ý lúc khai trương.
- `workspaces.settings["modules"]` — 12 module bật/tắt: đặt lịch, thu ngân, thẻ
  liệu trình, ví, điểm thưởng, hoa hồng, kho, hồ sơ điều trị, phiếu đồng ý, đánh
  giá, chat, khách vãng lai.
- `workspaces.settings["business"]` — ~50 tham số nghiệp vụ (bước giờ, thời gian
  đặt trước, hạn huỷ, dọn phòng, VAT, tip, hạn thẻ, % hoa hồng…). Từng **cơ sở**
  ghi đè được qua `branches.settings`.
- `workspaces.theme` / `branding` — màu, phông, logo, slogan, cách gọi khách/KTV.

Xem `app/models/concerns/business_settings.rb` cho danh sách đầy đủ kèm lý do
của từng giá trị mặc định.

## Chạy

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/dev                       # http://localhost:3013
```

Seed dựng một spa demo hai cơ sở, 11 phòng, 9 nhân sự, danh mục dịch vụ, gói
thẻ, ca làm 5 tuần và ~60 lịch hẹn + bill lịch sử để mọi báo cáo có dữ liệu thật.
Tài khoản seed xem ở `CLAUDE.md`.

## Kiểm thử

```bash
bin/rails test
```

108 test, trong đó:

- `test/services/slot_finder_test.rb` — 23 test bám từng luật xếp lịch (giờ mở
  cửa, ngày nghỉ, nghỉ phép, dọn phòng, sức chứa, loại phòng, KTV chỉ định, giới
  tính KTV, massage đôi, lead time, chỗ giữ tạm).
- `test/services/checkout_test.rb` — 16 test cho tiền (điểm, hoa hồng, ví, trừ
  buổi đúng một lần, huỷ bill hoàn lại mọi thứ, VAT gồm/chưa gồm, chia giảm giá)
  + 4 test cách ly dữ liệu giữa các tenant.
- `test/integration/page_smoke_test.rb` — mọi trang GET của ba cổng phải render,
  cộng luồng đăng nhập khách và luồng đặt lịch ba bước.

## Trạng thái & việc còn lại

Đã xong: nền tảng multi-tenant, cơ sở/phòng, nhân sự & ca làm, khách hàng, danh
mục dịch vụ, engine xếp lịch, lịch quầy + hàng chờ, app khách tự đặt lịch, thu
ngân, thẻ liệu trình, ví, điểm, hoa hồng, báo cáo.

Chưa làm (theo thứ tự đề xuất): hồ sơ điều trị kèm ảnh tiến trình & phiếu đồng
ý; kho vật tư + định mức tiêu hao; đánh giá sau buổi; nhắc lịch tự động qua
Zalo ZNS/SMS; đặt cọc online qua PayOS; bán thẻ trên app khách; AI gợi ý lấp
lịch trống; xuất Excel cho kế toán.
