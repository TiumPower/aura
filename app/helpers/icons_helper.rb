module IconsHelper
  # Inline line-icon set (24×24, currentColor stroke) for the customer app.
  ICONS = {
    home:    %(<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V20a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V9.5"/>),
    wallet:  %(<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10h18"/><circle cx="17" cy="14" r="1.4" fill="currentColor" stroke="none"/>),
    gift:    %(<rect x="4" y="9" width="16" height="11" rx="2"/><path d="M4 13h16M12 9v11"/><path d="M12 9C10 9 8 8 8 6.5S9 4 10 4.5 12 7 12 9Zm0 0c2 0 4-1 4-2.5S15 4 14 4.5 12 7 12 9Z"/>),
    scan:    %(<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2"/><path d="M4 12h16"/>),
    qrcode:  %(<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2M18 14h2M20 16v2M14 18v2h2M18 20h2" stroke-linecap="round"/>),
    wheel:   %(<circle cx="12" cy="12" r="9"/><path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6 5.6 18.4"/><circle cx="12" cy="12" r="2.2" fill="currentColor" stroke="none"/>),
    user:    %(<circle cx="12" cy="8" r="4"/><path d="M4 20c0-3.5 3.6-6 8-6s8 2.5 8 6"/>),
    bell:    %(<path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6"/><path d="M10 19a2 2 0 0 0 4 0"/>),
    gear:    %(<circle cx="12" cy="12" r="3.2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9 17 7M7 17l-2.1 2.1"/>),
    stamp:   %(<circle cx="12" cy="12" r="8"/><path d="m8.5 12 2.3 2.3 4.7-4.7"/>),
    target:  %(<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/>),
    medal:   %(<circle cx="12" cy="14" r="6"/><path d="m9 4 3 5 3-5"/><path d="m10.5 13.5 1.5 1.5 3-3" stroke-linecap="round"/>),
    users:   %(<circle cx="9" cy="8" r="3.2"/><path d="M3 19c0-3 2.7-5 6-5s6 2 6 5"/><path d="M16 5.5a3 3 0 0 1 0 5.6M17 19c0-2.2-1-3.8-2.5-4.6"/>),
    history: %(<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1"/><path d="M3.5 4v3.5H7" stroke-linecap="round"/><path d="M12 8v4.2l2.8 1.7" stroke-linecap="round"/>),
    eye:     %(<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="3"/>),
    eye_off: %(<path d="M3 3l18 18" stroke-linecap="round"/><path d="M10.6 5.1A10.4 10.4 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a17 17 0 0 1-3.2 3.9M6.4 6.4A16.6 16.6 0 0 0 2.5 12S6 18.5 12 18.5a10 10 0 0 0 4-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>),
    pause:   %(<rect x="7" y="5" width="3.4" height="14" rx="1.2"/><rect x="13.6" y="5" width="3.4" height="14" rx="1.2"/>),
    check:   %(<path d="M4.5 12.5 9.5 17.5 19.5 6.5" stroke-linecap="round"/>),
    launch:  %(<path d="M14 4h6v6" stroke-linecap="round"/><path d="M20 4 10 14" stroke-linecap="round"/><path d="M18 13.5V19a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5.5" stroke-linecap="round"/>),
    trash:   %(<path d="M4 7h16" stroke-linecap="round"/><path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/><path d="M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12"/><path d="M10 11v6M14 11v6" stroke-linecap="round"/>),
    chat:    %(<path d="M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9l-4 4v-4H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z"/><path d="M8 10h8M8 13h5" stroke-linecap="round"/>),
    wrench:  %(<path d="M14.5 6.5a3.6 3.6 0 0 1 4.6 4.6l-8 8a2.2 2.2 0 0 1-3.1-3.1l8-8Z"/><path d="M14.5 6.5 9 3.5 3.5 5 5 9l3.5 1.5" stroke-linecap="round"/>),
    receipt: %(<path d="M6 3h12v18l-3-1.6-3 1.6-3-1.6L6 21V3Z"/><path d="M9 8h6M9 12h6" stroke-linecap="round"/>),
    camera:  %(<path d="M3 8a2 2 0 0 1 2-2h1.5l1-1.6a1 1 0 0 1 .85-.4h3.3a1 1 0 0 1 .85.4L16.5 6H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8Z"/><circle cx="12" cy="12.5" r="3.2"/>),
    doc:     %(<path d="M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M13 3v5h5" stroke-linejoin="round"/><path d="M9 13h6M9 16.5h6" stroke-linecap="round"/>),
    chevron: %(<path d="m9 6 6 6-6 6" stroke-linecap="round" stroke-linejoin="round"/>),
    arrow_left: %(<path d="M19 12H5M11 6l-6 6 6 6" stroke-linecap="round" stroke-linejoin="round"/>),
    send:    %(<path d="M11 13 21 3M21 3l-6.4 18-3.6-8.2L3 9.4 21 3Z" stroke-linejoin="round"/>),
    paperclip: %(<path d="M20 11.5 12 19.5a4.5 4.5 0 0 1-6.4-6.4l8-8a3 3 0 0 1 4.3 4.3l-7.6 7.6a1.5 1.5 0 0 1-2.2-2.1l6.9-6.9" stroke-linecap="round"/>),
    plus:    %(<path d="M12 5v14M5 12h14" stroke-linecap="round"/>),
    image:   %(<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="8.5" cy="9.5" r="1.7"/><path d="m4 18 5-4.5 4 3L16.5 12 20 15.5" stroke-linecap="round" stroke-linejoin="round"/>),
    calendar: %(<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 9.5h17M8 3v4M16 3v4" stroke-linecap="round"/>),
    card:    %(<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 9.5h18M7 15h4" stroke-linecap="round"/>),
    sparkles: %(<path d="M12 3.2 13.7 8 18.5 9.6 13.7 11.2 12 16l-1.7-4.8L5.5 9.6 10.3 8 12 3.2Z" stroke-linejoin="round"/><path d="m18.5 14 .9 2.4 2.4.9-2.4.9-.9 2.4-.9-2.4-2.4-.9 2.4-.9.9-2.4Z" stroke-linejoin="round"/>),
    alert:   %(<path d="M12 4 2.6 20h18.8L12 4Z" stroke-linejoin="round"/><path d="M12 10v4.4" stroke-linecap="round"/><circle cx="12" cy="17.4" r="1" fill="currentColor" stroke="none"/>),
    shield:  %(<path d="M12 3 5 6v5c0 4.6 3 7.6 7 9 4-1.4 7-4.4 7-9V6l-7-3Z" stroke-linejoin="round"/><path d="m9 12 2 2 4-4" stroke-linecap="round"/>),
    phone:   %(<path d="M5.5 4h3L10 8.3l-2 1.4a12 12 0 0 0 5 5l1.4-2 4.3 1.5V19a2 2 0 0 1-2.2 2A16 16 0 0 1 3.5 6.2 2 2 0 0 1 5.5 4Z" stroke-linejoin="round"/>),
    mail:    %(<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m4.5 7.5 7.5 5.5 7.5-5.5" stroke-linecap="round" stroke-linejoin="round"/>),
    logout:  %(<path d="M14 4H6a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h8" stroke-linecap="round"/><path d="M18 12H9M15 8l3 4-3 4" stroke-linecap="round" stroke-linejoin="round"/>),
    edit:    %(<path d="M15.2 5.4 18.6 8.8M4 20l.9-3.6L15.5 5.8a2 2 0 0 1 2.8 0l.1.1a2 2 0 0 1 0 2.8L7.6 19.1 4 20Z" stroke-linejoin="round"/>),
    bolt:    %(<path d="M13 3 5.5 13.2H11l-1 7.8 8.5-11H13l1-7Z" stroke-linejoin="round"/>),
    drop:    %(<path d="M12 3.5s6 6.2 6 10.5a6 6 0 0 1-12 0C6 9.7 12 3.5 12 3.5Z" stroke-linejoin="round"/>),
    clock:   %(<circle cx="12" cy="12" r="8.5"/><path d="M12 7.2v5l3.4 2" stroke-linecap="round" stroke-linejoin="round"/>),
    info:    %(<circle cx="12" cy="12" r="9"/><path d="M12 11v5.2" stroke-linecap="round"/><circle cx="12" cy="7.9" r="1" fill="currentColor" stroke="none"/>),
    building: %(<rect x="5" y="3" width="14" height="18" rx="2.5"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2M10 21v-2.5h4V21" stroke-linecap="round"/>),
    key:     %(<circle cx="8" cy="15" r="4.5"/><path d="m11 12 8-8M16 4l3 0 0 3M14.5 6.5 17 9" stroke-linecap="round" stroke-linejoin="round"/>),
    download: %(<path d="M12 3.5v11M8 10.5l4 4 4-4M5 20h14" stroke-linecap="round" stroke-linejoin="round"/>),
    x:       %(<path d="M6 6l12 12M18 6 6 18" stroke-linecap="round"/>)
  }.freeze

  def ui_icon(name, size: 24, klass: nil, stroke: 1.8)
    body = ICONS[name.to_sym] or return "".html_safe
    attrs = %(viewBox="0 0 24 24" width="#{size}" height="#{size}" fill="none" stroke="currentColor" stroke-width="#{stroke}" stroke-linejoin="round" stroke-linecap="round" class="#{klass}" aria-hidden="true")
    "<svg #{attrs}>#{body}</svg>".html_safe
  end
end
