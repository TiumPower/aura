require "test_helper"

# `form_with` chỉ chuyển một danh sách ngắn các tuỳ chọn ra thẻ <form>:
# id, class, multipart, method, data, authenticity_token. Mọi thuộc tính khác —
# kể cả `style` — bị BỎ IM LẶNG nếu không bọc trong `html:`.
#
# Lỗi này đã làm 31 form trên cả ba cổng mất sạch layout: form khai
# `display:grid; gap:8px` nhưng render ra <form> trần, nên các ô xếp chồng và
# DÍNH VÀO NHAU. Không có gì báo lỗi: view render bình thường, mọi test nội dung
# xanh, HTTP 200. Test này quét toàn bộ view để nó không quay lại.
class FormWithStyleTest < ActiveSupport::TestCase
  test "không form_with nào đặt style ở cấp ngoài" do
    offenders = []
    Dir.glob(Rails.root.join("app/views/**/*.erb")).sort.each do |path|
      src = File.read(path)
      src.enum_for(:scan, /form_with\b/).each do
        at = Regexp.last_match.begin(0)
        tail = src[at, 800]
        stop = tail =~ /\sdo\b/
        call = stop ? tail[0, stop] : tail[0, 200]
        next unless call.match?(/(\A|[,\s])style:/) && !call.include?("html:")
        offenders << "#{path.sub(Rails.root.to_s + '/', '')}:#{src[0, at].count("\n") + 1}"
      end
    end
    assert_empty offenders, <<~MSG
      #{offenders.size} form_with đặt `style:` ở cấp ngoài — Rails sẽ bỏ nó và
      form mất layout. Bọc lại thành `html: { style: "…" }`, hoặc tốt hơn là
      chuyển sang `class:` (form_with CÓ chuyển class ra thẻ form).
      #{offenders.join("\n")}
    MSG
  end
end
