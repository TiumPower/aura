# Tự động deploy

`deploy.yml` chạy `cap production deploy` ngay sau khi workflow **CI** kết thúc
trên nhánh `main` — **kể cả khi CI đỏ**. Đó là lựa chọn có chủ ý; phần "Vì sao"
ở cuối trang nói rõ đánh đổi. Giống hệt cấu hình của `loyalty`.

`rollback.yml` chạy `cap production deploy:rollback` khi bấm tay, để có đường
lùi nhanh khi một bản đỏ làm hỏng production.

## Máy chủ lấy mã từ đâu

Khi deploy tay, máy chủ `103.116.38.152` mượn SSH agent của máy đang deploy
(`forward_agent: true` trong `config/deploy/production.rb`) để kéo mã từ
GitHub — nó không có khoá GitHub nào của riêng mình.

GitHub Actions không mượn được như vậy, và **tổ chức TiumPower tắt Deploy
keys** nên cũng không thể cấp cho máy chủ một khoá riêng. Thay vào đó, workflow
truyền `REPO_URL` dạng HTTPS kèm `GITHUB_TOKEN` — token GitHub tự cấp cho mỗi
lần chạy và **tự hết hạn khi lần chạy kết thúc**:

```
https://x-access-token:<token>@github.com/TiumPower/aura.git
```

`config/deploy.rb` đọc `REPO_URL` nếu có, không thì dùng URL SSH như cũ — nên
deploy tay không đổi gì.

Capistrano ghi URL đó vào config của git mirror trên máy chủ, nên sau mỗi lần
deploy (kể cả khi hỏng) workflow gọi `cap production deploy:scrub_repo_url` để
trả về URL SSH. Token đã chết rồi, nhưng không để bí mật nằm lại trên đĩa.

Hệ quả: **không cần Deploy key, không cần GitHub App, không có bí mật dài hạn
nào phải xoay vòng.**

## Hai secret cần có

Bốn app (`loyalty`, `estate`, `aura`, `xstudio`) deploy lên **cùng một máy chủ
bằng cùng một user `deploy`**, nên dùng chung đúng một khoá. Cách gọn nhất là
đặt ở cấp tổ chức một lần, thay vì lặp lại ở từng repo:

**TiumPower → Settings → Secrets and variables → Actions → New organization
secret**, phạm vi *Selected repositories* gồm cả bốn repo.

| Tên secret | Lấy từ đâu |
|---|---|
| `DEPLOY_SSH_KEY` | `cat ~/.ssh/loyalty_ci` — **toàn bộ** khoá riêng, kể cả hai dòng `-----BEGIN/END-----` |
| `DEPLOY_KNOWN_HOSTS` | `ssh-keyscan 103.116.38.152 2>/dev/null \| grep -v '^#'` |

Khoá công khai đã nằm trong `~deploy/.ssh/authorized_keys` trên máy chủ (cài
khi dựng auto-deploy cho `loyalty`), và vì cùng một user nên nó mở được cả bốn
app — không phải cài lại.

`DEPLOY_KNOWN_HOSTS` để ghim khoá máy chủ. Mỗi lần chạy là một runner mới tinh,
nên nếu tắt kiểm tra bằng `StrictHostKeyChecking=no` thì coi như không xác thực
máy chủ lần nào cả.

## Thử

**Actions → Deploy → Run workflow**. Chạy tay được thì lần push tiếp theo lên
`main` sẽ tự deploy sau khi CI xong.

## Những gì workflow cố tình KHÔNG làm

- **Không deploy khi CI bị huỷ (`cancelled`).** Huỷ gần như luôn là do có
  commit mới đè lên, và CI của commit mới sẽ tự deploy. Đỏ thì vẫn deploy —
  chỉ "huỷ" mới bỏ qua.
- **Không deploy từ pull request.** Chỉ nhận CI của `push` lên `main`.
- **Không chạy hai deploy cùng lúc.** `concurrency: deploy-production` xếp
  hàng, và không huỷ lần đang chạy giữa chừng — cắt ngang một `cap deploy` để
  lại thư mục release dở dang trên máy chủ.

## Vì sao vẫn deploy khi CI đỏ — và cái giá

Yêu cầu của chủ sản phẩm. Thời điểm viết tài liệu này, `bin/rubocop` của app
này báo **822 lỗi style**, nên job `lint` đỏ ở **mọi** lần push — "chỉ
deploy khi CI xanh" sẽ chặn mọi bản deploy.

Cái giá có thật: từ giờ một commit làm **hỏng test** cũng ra tới khách hàng, y
như một commit chỉ sai khoảng trắng. Hai thứ bù lại:

1. **Capistrano đổi release bằng symlink.** Một deploy *hỏng giữa chừng* để
   nguyên bản cũ đang chạy — production không sập. Rủi ro thật là deploy
   *thành công* với mã sai.
2. **Workflow Rollback** quay về release trước trong vài giây.

Đường về một CI đáng để chặn deploy:

1. `bin/rubocop -A` tự sửa 433 lỗi, rồi `bin/rubocop --auto-gen-config` gạt
   phần còn lại sang `.rubocop_todo.yml` — hoặc bỏ hẳn job `lint` khỏi
   `ci.yml` nếu không định dùng.
2. Rồi thêm `github.event.workflow_run.conclusion == 'success'` vào điều kiện
   `if` trong `deploy.yml` — đúng một dòng.
