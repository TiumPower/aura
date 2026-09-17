module MerchantHelper
  # Renders a "Back" control into the merchant top bar (see layouts/merchant.html.erb).
  # It returns to the real previous page via browser history, falling back to `url`
  # when there is no history (e.g. the page was opened directly). Call once near the
  # top of any drill-down screen: `<% merchant_back merchant_campaigns_path %>`.
  def merchant_back(url, label = nil)
    label ||= t("merchant.back")
    content_for :back, link_to("← #{label}", url,
      data: { controller: "goback", action: "click->goback#back" },
      style: "display:inline-flex; align-items:center; gap:4px; color:var(--ink-2); " \
             "text-decoration:none; font-size:13px; font-weight:600; padding:6px 12px; " \
             "border:1px solid var(--line); border-radius:999px; white-space:nowrap; background:#fff;")
    nil
  end

  # ---- Billing settings inheritance (BillingSettings cascade) -------------
  # Placeholder showing what the field would use if left blank.
  def inherit_ph(record, key)
    val = record.inherited_setting(key)
    return "Để trống = kế thừa" if val.blank? || val.to_s == "0"
    case key.to_s
    when "water_mode" then val.to_s == "fixed" ? "Cố định" : "Theo đồng hồ"
    else "Để trống = kế thừa #{number_with_delimiter(val.to_i)}"
    end
  end

  # Small grey line under the field saying where the inherited value comes from.
  def inherit_hint(record, key)
    return if record.own_setting(key).present?
    val = record.inherited_setting(key)
    return if val.blank? || val.to_s == "0"
    src = record.setting_source(key)
    from = case src
           when :inherited then record.is_a?(Unit) ? "toà nhà" : "Cài đặt chung"
           else "mặc định hệ thống"
           end
    tag.div("Đang kế thừa #{number_with_delimiter(val.to_i)} từ #{from}.",
            style: "font-size:12px; color:var(--ink-2); margin-top:5px;")
  end
end
