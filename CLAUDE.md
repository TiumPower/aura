# Aura — ghi chú cho Claude Code

Đọc `README.md` trước. File này chỉ ghi những thứ dễ vấp mà đọc code không thấy ngay.

## Bẫy đã gặp

- **KHÔNG tạo module `Booking::`, `Order::`, `Service::`, `Member::`.** Đã có model
  cùng tên; namespace trùng tên model là nổ dưới Zeitwerk (đúng lỗi Loyalty gặp
  với `Member` và BƠI ĐẠT gặp với `Teacher`). Các service liên quan để ở tên cấp
  cao: `SlotFinder`, `BookingScheduler`, `Checkout`. Cổng nhân sự dùng
  `Merchant::`, cổng khách dùng `Customer::` — hai tên này không trùng model nào.
- **Ghim `json ~> 2.21`.** json 3.x bỏ keyword `quirks_mode` mà ActiveRecord 7.2
  còn dùng khi ghi cột jsonb → mọi migration tạo bảng có jsonb đều nổ.
- **`member_root` phải khai bằng `get ""`,** không phải `root` — với `root`, Rails
  sinh URL thành `/?workspace_slug=x` thay vì `/w/x` ở chế độ đường dẫn.
- **Đăng nhập khách nằm ở `/vao`, không phải `/login`.** Segment `(/w/:slug)` là
  tuỳ chọn nên ở chế độ subdomain `login` rút thành đúng `/login` và đụng route
  đăng nhập của nhân sự khai phía trên.
- **`/w/:x` nhận CẢ slug lẫn subdomain.** Slug của "Aura Spa Sài Gòn" là
  `aura-spa-sai-gon` còn subdomain là `auraspa`; bắt người dùng nhớ đúng một
  trong hai chuỗi chỉ tổ 404.
- **`scope :at_branch` của StaffMember dùng subquery, không dùng join + DISTINCT.**
  `SELECT DISTINCT` đụng với `ORDER BY NULLIF(code,'')` và Postgres từ chối cả
  câu truy vấn ("for SELECT DISTINCT, ORDER BY expressions must appear in select list").
- **`total` có ở cả `orders` và `order_items`.** Mọi `sum`/`order` trên
  `OrderItem.joins(:order)` phải viết rõ `order_items.total`, nếu không Postgres
  báo "column reference total is ambiguous".
- **Đừng vá `Time`/`TimeWithZone` bằng initializer** để có `floor_to_hour`.
  `ActiveSupport.on_load(:active_support_time_with_zone)` không phải load hook
  thật → method không bao giờ được thêm và lỗi chỉ lộ ra lúc render lịch. Hai
  helper đó là method private của `Merchant::BookingsController`.
- **Nhãn thứ ngắn dùng `Branch.weekday_short`,** đừng `"Thứ hai".sub("Thứ ", "T")`
  — nó ra "Thai".
- **Chạy `bin/rails tailwindcss:build` sau khi sửa CSS**, hoặc dùng `bin/dev`.
  `rails server` trần KHÔNG biên dịch Tailwind.
- **Controller Stimulus nạp kiểu eager toàn bộ.** Thêm file vào
  `app/javascript/controllers/` là nó tải trên MỌI trang của cả ba cổng, kể cả
  PWA chạy 4G. Đừng để lại controller không dùng.
- **Sửa locale phải nhìn cả hai file.** `config.i18n.fallbacks = [:en]`, nên xoá
  một khoá ở riêng `vi.yml` KHÔNG làm test đỏ — nó lặng lẽ rơi về tiếng Anh và
  người Việt thấy chuỗi tiếng Anh.
- **`tld_length` suy từ `PLATFORM_HOST`, đừng viết cứng.** Host nền tảng ba nhãn
  (`aura.czin.net`) mà tld_length mặc định là 1 thì Rails đọc chính apex thành
  "subdomain aura".
- **Test trang `/merchant/commissions` và `/merchant/reports` phải có dữ liệu thật.**
  Kỳ rỗng không đi qua phần lớn mã của mấy trang đó — lỗi
  `merchant_approve_commissions_path` đã lọt qua smoke test đúng vì lý do này.
- **KTV phải có ca làm mới nhận được khách.** Mọi test đặt lịch phải tạo
  `staff_shifts` phủ đúng khoảng giờ, nếu không engine từ chối đúng như thiết kế
  và test đỏ vì lý do không liên quan.

## Quy ước phải giữ

- **Một sự thật một nguồn.** `SlotFinder` là nơi DUY NHẤT trả lời "còn chỗ không";
  `BookingScheduler` là nơi DUY NHẤT tạo/đổi lịch; `Checkout` là nơi DUY NHẤT
  thay đổi tiền, buổi trong thẻ, ví, điểm và hoa hồng; `Order#recalculate!` là
  nơi DUY NHẤT tính lại con số của bill. Không màn hình nào được tự cộng tay.
- **Quy tắc nghiệp vụ còn tranh luận đọc từ `workspace.setting(...)` hoặc
  `branch.setting(...)`, không hard-code.** Danh sách đầy đủ ở
  `app/models/concerns/business_settings.rb`; chi nhánh ghi đè được workspace.
- **Kiểm tra trùng chạy LẠI bên trong transaction trước khi ghi.** `BookingHold`
  chỉ làm hẹp cửa sổ tranh chấp, không đóng được nó.
- **Buổi trong thẻ chỉ bị trừ khi ĐÓNG BILL,** không phải khi mở bill. Trước đó
  khách còn đổi ý, và một buổi bị trừ oan rất khó giải thích.
- **Mỗi lần trừ/hoàn buổi phải để lại dấu** (`package_credit_uses`). Đừng bao giờ
  `update_all(used_sessions: ...)`.
- **Phụ thu hạng KTV chỉ tính khi khách TỰ chọn người đó.** Khách bấm "spa tự
  xếp" mà bị thu thêm là thu tiền cho thứ khách không chọn.
- **Giá hứa ở màn xác nhận = giá ghi vào lịch hẹn.** Ưu đãi hạng thẻ được ghi
  vào `booking_items.discount_amount`, chia về từng dòng và khớp tổng tuyệt đối.
- **Giảm giá cả bill chia về từng dòng,** không treo ở cấp bill — treo ở cấp bill
  làm doanh thu từng dịch vụ bị phóng đại trong báo cáo.
- **RevPATH chỉ tính doanh thu DỊCH VỤ.** Tiền bán thẻ/nạp ví là thu trước cho
  các buổi sau; cộng vào sẽ làm tháng bán được thẻ trông như tháng vận hành giỏi.
- **Mọi id đến từ form phải kiểm tra thuộc đúng workspace** (xem
  `StaffMembersController#staff_params`). `acts_as_tenant` lọc phần đọc, không tự
  chặn phần ghi id lạ.
- **Mọi thao tác ghi có tranh chấp gọi `audit!(...)`** — sửa giá, tặng buổi, huỷ
  bill, đổi hoa hồng là bốn chỗ spa nào cũng có lúc cần biết ai đã làm gì.
- **Module bật/tắt kiểm bằng `workspace.feature?(key)`** (gói cho phép VÀ spa đã
  bật), không phải `module?` trơ.

## Chạy nhanh

```bash
bin/dev                                     # port 3013 (kèm tailwind watch)
bin/rails db:drop db:create db:migrate db:seed
bin/rails test                              # toàn bộ
bin/rails test test/services/slot_finder_test.rb
bin/rails test test/services/checkout_test.rb
bundle exec brakeman -q --no-pager
```

Tài khoản seed (chỉ dev): chủ spa `chu@aura.local` / `aura1234`, lễ tân
`letan@aura.local`, super admin `quocvietlee@gmail.com`, khách demo đăng nhập
bằng SĐT `0905111222` (mã OTP hiện trên màn hình ở dev).
