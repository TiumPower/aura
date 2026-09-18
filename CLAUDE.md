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

## Bẫy khi deploy (đã vấp thật trên production)

- **`app/assets/builds/.keep` PHẢI được theo dõi trong git.** Sprockets nạp danh
  sách đường dẫn asset lúc KHỞI ĐỘNG; thư mục chưa tồn tại thì tailwind.css do
  `tailwindcss:build` sinh ra ngay sau đó không được biên dịch → **mọi trang
  500** trong khi `/up` vẫn 200 (giám sát không thấy gì).
- **Hot restart USR2 phải có `directory` + `prune_bundler` trong puma.rb.**
  systemd giải symlink `current` lúc start nên cwd của Puma là thư mục RELEASE
  CŨ; USR2 re-exec từ chính cwd đó → deploy "thành công" nhưng **Puma vẫn chạy
  code cũ**. Lỗi này tệ hơn downtime vì nó im lặng. Kiểm chứng bằng
  `readlink -f /proc/$(systemctl --user show aura_puma_production -p MainPID --value)/cwd`
  — phải bằng `readlink -f /var/www/aura/current`.
- **Đường dẫn trong puma.rb đọc từ `APP_ROOT`, đừng suy từ `__FILE__`** —
  `__FILE__` chính là đường dẫn release đã giải symlink.
- **`ExecReload` phải là USR2, không phải USR1.** USR1 là phased restart, chỉ có
  tác dụng ở cluster mode; Aura chạy single mode nên USR1 không làm gì.
- **Phải ghi đè chính `puma:restart`, không thêm task mới.** Plugin systemd của
  capistrano3-puma có hook riêng gọi `puma:restart` sau deploy, nên thêm
  `hot_restart` riêng thì vẫn bị nó restart cứng ngay sau đó.
- **`cap puma:install` sinh unit HỎNG** (đặt env ngay trong ExecStart). Bản đúng
  nằm ở `config/systemd/`; chạy `puma:install` xong phải chép lại và
  `systemctl --user daemon-reload`.
- **`ed25519` + `bcrypt_pbkdf` phải có trong Gemfile.** Khoá SSH định dạng
  OPENSSH mới (kể cả RSA) cần hai gem này, thiếu thì `cap deploy` chết ở
  `rbenv:validate`.
- **`number_to_delimited` KHÔNG phải helper của view** (nó là method của
  `ActiveSupport::NumberHelper`); helper là `number_with_delimiter`. Trang
  `/merchant/staff` đã 500 trên production trong khi 108 test vẫn xanh, vì nhánh
  đó chỉ render khi KTV có phụ thu > 0.
- **Giá trị có dấu cách trong `shared/.env` phải bọc ngoặc kép.** systemd
  `EnvironmentFile` chịu được, nhưng mọi script `. .env` sẽ vỡ.
- **Máy chủ chật RAM (5 app Rails / 3.7GB).** Aura chạy `WEB_CONCURRENCY=0`
  (single mode) và sidekiq concurrency 3. Đừng nâng lên 2 worker mà không thêm RAM.

## Bẫy "test xanh mà màn hình nói sai"

Bốn lỗi dưới đây cùng lọt qua 131 test và cùng trả HTTP 200. Không lỗi nào làm
mã nổ — chúng chỉ làm màn hình nói sai, nên **mọi kiểm tra dựa vào mã 200 đều
mù với chúng**. Sửa xong rồi, nhưng dạng lỗi thì còn.

- **`LIVE_STATUSES` gồm cả `completed`** vì buổi đã xong VẪN chiếm phòng
  (`SlotFinder` phải đếm nó). Đừng dùng `live?` để hỏi "còn huỷ/đổi được không"
  — hỏi `cancel_window_closed?`. Trước khi sửa, buổi xong từ tháng trước hiện
  "Đã sát giờ hẹn nên không tự huỷ được".
- **`Order#subtotal` đã trừ giảm giá** (nó cộng từ `order_items.total`, mà
  `total` từng dòng = `unit_price × qty − discount_amount`). In nó cạnh dòng
  "Giảm giá" là ra dãy "Tạm tính 360.000 − giảm 40.000 = khách trả 360.000".
  Hiển thị dùng `subtotal_before_discount` và `OrderItem#gross_total`.
- **Nhánh rỗng phải nói đúng phạm vi của nó.** `/lich-hen` in "Bạn chưa có lịch
  hẹn nào" ngay trên danh sách 7 buổi đã qua, vì nhánh đó chỉ xét `@upcoming`.
- **Tàn dư của bản fork.** `public/404|422|500.html` và `layouts/print.html.erb`
  còn tên "Estate"/"Hợp đồng". Sau khi fork phải `grep -rn "\bEstate\b" app/ public/`.

Cách review đúng: crawler đi theo href thật (nhớ `html.unescape` — `&amp;` làm
mọi URL nhiều tham số bị gửi sai), soi nội dung tìm `translation missing`,
`>nil<`, `#<Model`, `\bEstate\b`; rồi **đọc bằng mắt** các trang cốt lõi —
dãy số phải cộng ra được, câu chữ phải khớp dữ liệu ngay bên dưới nó.

## `form_with` bỏ im lặng mọi thuộc tính lạ

**`form_with` chỉ chuyển `id`, `class`, `multipart`, `method`, `data`,
`authenticity_token` ra thẻ `<form>`.** Mọi thứ khác — kể cả `style` — bị BỎ
KHÔNG BÁO GÌ nếu không bọc trong `html: { ... }`.

Đã vấp thật: **31 form ở cả ba cổng** khai `style: "display:grid; gap:8px"` ở
cấp ngoài, render ra `<form>` trần, nên các ô xếp chồng và DÍNH VÀO NHAU. Cả
trang thu ngân vỡ layout. Không có gì báo lỗi — view render bình thường, HTTP
200, 134 test nội dung xanh.

- **Ưu tiên `class:`** thay vì `style:`: form_with CÓ chuyển class ra thẻ form,
  nên dùng class là không vấp lại được (xem `.pos-add`, `.pos-pay-row`).
- `test/views/form_with_style_test.rb` quét toàn bộ view và đỏ nếu lỗi quay lại.
- `test/system/merchant_spacing_test.rb` + `pos_layout_test.rb` ĐO hình học thật
  trên Chrome. Helper `cramped_pairs` ở `ApplicationSystemTestCase` không đo gap
  trần giữa hai hộp — kiểu "danh sách có vạch phân cách" hở 0px là hợp lệ vì mỗi
  dòng tự có padding. Nó đo KHOẢNG THỞ: padding chỉ tính là khoảng cách khi cạnh
  đó không có viền/nền. Hai ô có viền mà viền chạm nhau thì luôn là dính.
- **Cột nút trong bảng nhiều dòng phải CỐ ĐỊNH, không `auto`** — nhãn dài khác
  nhau làm các ô nhập so le (xem `.pos-pay-row`).

## Soát UI bằng ĐO hình học, không bằng mắt thường

`test/application_system_test_case.rb` có bốn phép đo dùng cho cả ba cổng:
`cramped_pairs` (ô dính nhau), `horizontal_overflow` (trang cuộn ngang),
`tiny_targets` (vùng bấm < 24px — mức tối thiểu WCAG 2.2), `clipped_text`.
Ba bài soát: `merchant_spacing_test`, `customer_ui_audit_test`,
`admin_ui_audit_test` — chạy ở 390px và 1400px.

Những gì chúng đã tìm ra và phải giữ:

- **Inline style KHÔNG khai được media query.** Lưới hai cột có cột phụ cố định
  buộc phải là class (`.l-2col`). Trang chi tiết workspace ở cổng admin từng
  viết `grid-template-columns:1fr 320px` inline và tràn ngang 179px trên điện
  thoại: cột phụ ăn 320px trong 358px.
- **Bảng nhiều cột bọc trong `.l-tablewrap`** — cho BẢNG cuộn ngang, đừng để cả
  TRANG cuộn ngang (`/admin/workspaces` từng tràn 164px).
- **Đừng ghi đè `grid-template-columns` của `.l-kpis`** — nó đã là
  `auto-fit minmax(150px,1fr)`. Ghi đè bằng `repeat(3,1fr)` cho bốn thẻ là vừa
  tràn ngang vừa lệch hàng.
- **Đầu thẻ dùng `.l-cardhead`**, đừng flex `space-between` trơ: ở khổ hẹp tiêu
  đề vỡ giữa chữ và xen vào chú thích — "Doanh hoá đơn thuê bao đã / thu thanh toán".
- **Chip bấm được cao ≥34px** (`a.l-chip, button.l-chip…`); chip dùng làm nhãn
  tĩnh giữ nguyên cỡ. Link đứng riêng làm nhiệm vụ nút dùng `.l-textlink`.
- **Cổng admin cũng cần `_admin_tabbar`.** Sidebar ẩn từ ≤900px; trước khi có
  tabbar, mở cổng admin trên điện thoại là không đi được đâu ngoài trang đang
  xem. `.l-mtab` là lưới 5 cột nên số mục phải đúng 5.
- **Bẫy khi viết test:** `click_on` trả về TRƯỚC khi POST xong. Đọc DB ngay sau
  đó là đọc lúc request còn đang bay (OTP khách ra nil). Phải `assert_text` ở
  trang đích trước. Và checkbox/radio bọc trong `<label>`/`.l-switch` thì vùng
  bấm là label — đo ô input là dương tính giả.

## Popup lịch hẹn (lịch ngày & hàng chờ)

- **Cùng MỘT URL trả hai dạng.** `bookings#show` trả bản xem nhanh không layout
  khi `turbo_frame_request_id == "booking_peek"`, trả trang đầy đủ khi không.
  Nhờ vậy link vẫn mở được ở tab mới và JS hỏng thì vẫn dùng được.
- **`<dialog>` PHẢI định vị tường minh.** UA stylesheet căn giữa nó bằng
  `margin:auto`; reset CSS của app xoá margin nên hộp dán vào góc trên trái.
  Dùng `position:fixed; top:50%; left:50%; transform:translate(-50%,-50%)`.
  Đã có system test đo hình học thật (`test/system/booking_peek_test.rb`) —
  không assert nào về NỘI DUNG bắt được lỗi này.
- **Bắt cả sự kiện `close` của dialog,** không chỉ nút ✕: nhấn Esc thì
  `<dialog>` tự đóng mà không đi qua Stimulus, và frame giữ lại nội dung cũ.
- **Nút trong popup chạy tiếp TRONG popup.** `status` trả Turbo Stream vẽ lại
  ruột popup + các khối trên lịch khi có `cal_from`. Vị trí khối phụ thuộc khung
  giờ đang hiển thị nên KHÔNG suy được từ bản ghi — popup mang theo `cal_from`,
  và `CAL_PX` là hằng số để view và stream dùng cùng một con số.
- **Việc cần cân nhắc ở lại trang đầy đủ** (đổi giờ, gán lại KTV/phòng, ghi chú,
  huỷ có lý do): chúng cần nhìn cả ngày để quyết, nhồi vào popup là mời người ta
  quyết vội.

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

# deploy (repo bare trên server, không qua GitHub)
git push production main && bundle exec cap production deploy
bundle exec cap production deploy:seed        # chỉ lần đầu
```

## Deploy

Live tại **https://aura.czin.net** + `*.aura.czin.net`, cùng máy với
loyalty/estate/boidat/xstudio (`103.116.38.152`). Chi tiết hạ tầng: xem
`docs/DEPLOY.md`.

Tài khoản seed (chỉ dev): chủ spa `chu@aura.local` / `aura1234`, lễ tân
`letan@aura.local`, super admin `quocvietlee@gmail.com`, khách demo đăng nhập
bằng SĐT `0905111222` (mã OTP hiện trên màn hình ở dev).
