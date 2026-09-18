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
  # ---- Các phép đo khác, dùng cho việc soát UI cả ba cổng ------------------

  # Trang có tràn ngang (phải cuộn trái/phải) — lỗi nặng nhất trên điện thoại.
  def horizontal_overflow
    page.evaluate_script(<<~JS)
      (() => {
        const d = document.documentElement;
        const over = d.scrollWidth - d.clientWidth;
        if (over <= 1) return null;
        // Tìm phần tử nào chìa ra ngoài để biết sửa ở đâu.
        const w = d.clientWidth, culprits = [];
        document.querySelectorAll("body *").forEach(el => {
          const r = el.getBoundingClientRect();
          if (r.width === 0 || r.height === 0) return;
          if (r.right > w + 1 && getComputedStyle(el).position !== "fixed") {
            culprits.push(el.tagName.toLowerCase() +
              (el.className && typeof el.className === "string" ? "." + el.className.trim().split(/\s+/)[0] : "") +
              " chìa " + Math.round(r.right - w) + "px");
          }
        });
        return { over: over, culprits: [...new Set(culprits)].slice(0, 6) };
      })()
    JS
  end

  # Ô bấm quá nhỏ để bấm bằng ngón tay. Ngưỡng 24px là mức TỐI THIỂU của
  # WCAG 2.2 (khuyến nghị là 44px) — đặt ngưỡng cao hơn thì công tắc bật/tắt
  # cao 27px cũng bị báo, mà nó vẫn bấm được. Dưới 24px thì là bấm nhầm thật.
  def tiny_targets(min = 24)
    page.evaluate_script(<<~JS)
      (() => {
        const bad = [];
        document.querySelectorAll('a, button, [type="submit"], select, input:not([type="hidden"])').forEach(el => {
          // Checkbox/radio được bọc trong <label> (hoặc .l-switch) thì VÙNG BẤM
          // là label, không phải ô input — đo ô input là dương tính giả.
          if (["checkbox", "radio"].includes(el.type)) {
            const lab = el.closest("label, .l-switch");
            if (lab) { el = lab; }
          }
          const r = el.getBoundingClientRect();
          if (r.width === 0 || r.height === 0) return;           // ẩn
          if (getComputedStyle(el).display === "contents") return;
          if (r.height >= #{min}) return;
          const txt = (el.textContent || el.value || el.getAttribute("aria-label") || "").trim().slice(0, 24);
          bad.push(el.tagName.toLowerCase() + ' "' + txt + '" cao ' + Math.round(r.height) + "px");
        });
        return [...new Set(bad)];
      })()
    JS
  end

  # Chữ bị cắt: hộp có overflow ẩn mà nội dung rộng hơn, KHÔNG có ellipsis và
  # không có title để xem đầy đủ — người dùng mất thông tin mà không biết.
  def clipped_text
    page.evaluate_script(<<~JS)
      (() => {
        const bad = [];
        document.querySelectorAll("body *").forEach(el => {
          if (el.children.length > 0) return;                     // chỉ xét nút lá
          const cs = getComputedStyle(el);
          if (!["hidden", "clip"].includes(cs.overflowX)) return;
          if (cs.textOverflow === "ellipsis") return;
          if (el.title) return;
          if (el.scrollWidth <= el.clientWidth + 1) return;
          bad.push((el.textContent || "").trim().slice(0, 30) + " (cắt " +
                   (el.scrollWidth - el.clientWidth) + "px)");
        });
        return [...new Set(bad)].slice(0, 8);
      })()
    JS
  end
end
