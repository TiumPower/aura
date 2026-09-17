import { Controller } from "@hotwired/stimulus"

// Nạp các giờ CÒN TRỐNG THẬT cho form nhận lịch ở quầy. Danh sách giờ do server
// tính (SlotFinder), client chỉ hiển thị — nếu client tự sinh lưới giờ thì nó sẽ
// chào cả những giờ đã kín và lễ tân hứa sai với khách.
export default class extends Controller {
  static targets = ["service", "staff", "date", "party", "gender", "slots",
                    "time", "room", "staffPick", "picked"]

  connect() { this.load() }

  async load() {
    if (!this.hasSlotsTarget || !this.hasServiceTarget) return
    const url = new URL(this.element.dataset.slotsUrl || "/merchant/bookings/slots", window.location.origin)
    url.searchParams.set("branch_id", this.element.querySelector("[name=branch_id]").value)
    url.searchParams.set("service_id", this.serviceTarget.value)
    if (this.hasDateTarget)   url.searchParams.set("date", this.dateTarget.value)
    if (this.hasStaffTarget && this.staffTarget.value) url.searchParams.set("staff_member_id", this.staffTarget.value)
    if (this.hasPartyTarget)  url.searchParams.set("party_size", this.partyTarget.value)
    if (this.hasGenderTarget && this.genderTarget.value) url.searchParams.set("gender", this.genderTarget.value)

    this.slotsTarget.innerHTML = '<span style="font-size:13px;color:var(--ink-2)">Đang tải giờ trống…</span>'
    try {
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      const data = await res.json()
      this.render(data.slots || [])
    } catch (e) {
      this.slotsTarget.innerHTML = '<span style="font-size:13px;color:#B4402F">Không tải được giờ trống. Thử lại.</span>'
    }
  }

  render(slots) {
    if (!slots.length) {
      this.slotsTarget.innerHTML =
        '<span style="font-size:13px;color:#B4402F">Ngày này không còn chỗ cho lựa chọn hiện tại — thử đổi ngày, đổi KTV hoặc bỏ yêu cầu giới tính.</span>'
      return
    }
    this.slotsTarget.innerHTML = ""
    slots.forEach((s) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "bk-slot"
      btn.textContent = s.time
      btn.title = [s.room, s.staff].filter(Boolean).join(" · ")
      btn.addEventListener("click", () => this.pick(btn, s))
      this.slotsTarget.appendChild(btn)
    })
  }

  pick(btn, slot) {
    this.slotsTarget.querySelectorAll(".bk-slot").forEach((b) => b.classList.remove("on"))
    btn.classList.add("on")
    this.timeTarget.value = slot.time
    this.roomTarget.value = slot.room_id || ""
    // KTV do lễ tân chọn tay thắng gợi ý của engine.
    const manual = this.hasStaffTarget ? this.staffTarget.value : ""
    this.staffPickTarget.value = manual || slot.staff_id || ""
    if (this.hasPickedTarget) {
      this.pickedTarget.textContent =
        `Đã chọn ${slot.time}` + (slot.room ? ` · ${slot.room}` : "") + (slot.staff ? ` · ${slot.staff}` : "")
    }
  }
}
