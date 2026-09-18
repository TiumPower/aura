require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Khoảng thở nhỏ nhất giữa hai ô xếp trên dưới trong cùng một form, tính bằng px.
  MIN_GAP = 4

  # Trả về danh sách cặp ô DÍNH NHAU trên trang đang mở.
  #
  # Không đo gap trần giữa hai hộp, vì kiểu "danh sách có vạch phân cách" hoàn
  # toàn hợp lệ: hai dòng sát nhau nhưng mỗi dòng tự có padding bên trong. Đo
  # KHOẢNG THỞ THẬT SỰ: padding chỉ được tính là khoảng cách khi cạnh đó không
  # có viền hay nền — nghĩa là hộp chỉ để dàn trang. Hai ô CÓ viền mà viền chạm
  # nhau thì luôn là dính, dù bên trong chúng có padding bao nhiêu.
  def cramped_pairs
    page.evaluate_script(<<~JS)
      (() => {
        document.querySelectorAll("details").forEach(d => d.open = true);
        const painted = (cs, side) =>
          parseFloat(cs["border" + side + "Width"]) > 0 ||
          !["rgba(0, 0, 0, 0)", "transparent"].includes(cs.backgroundColor);
        const bad = [];
        document.querySelectorAll("form").forEach(f => {
          const kids = [...f.children].filter(c => {
            const r = c.getBoundingClientRect();
            return r.width > 0 && r.height > 0;
          });
          for (let i = 0; i < kids.length - 1; i++) {
            const a = kids[i], b = kids[i + 1];
            const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
            if (rb.top < ra.bottom - 2) continue; // cùng hàng, không phải trên dưới
            const ca = getComputedStyle(a), cb = getComputedStyle(b);
            const padA = painted(ca, "Bottom") ? 0 : parseFloat(ca.paddingBottom) || 0;
            const padB = painted(cb, "Top") ? 0 : parseFloat(cb.paddingTop) || 0;
            const breathe = (rb.top - ra.bottom) + padA + padB;
            if (breathe < #{MIN_GAP}) {
              bad.push((f.getAttribute("action") || "?").split("/").slice(-2).join("/") +
                       " → " + a.tagName + "/" + b.tagName + " thở " + Math.round(breathe) + "px");
            }
          }
        });
        return bad;
      })()
    JS
  end
end
