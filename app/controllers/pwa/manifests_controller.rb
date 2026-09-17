module Pwa
  class ManifestsController < ApplicationController
    include TenantResolver
    skip_before_action :set_locale, raise: false

    # Per-workspace web app manifest. The install name is the BUILDING of the
    # cơ sở khách hay tới (để icon trên máy khách mang tên đúng chỗ họ đến),
    # nếu không có thì lấy tên spa.
    def show
      @workspace = resolve_workspace
      render json: manifest_hash, content_type: "application/manifest+json"
    end

    # Landlord management app (installable from /merchant).
    def merchant
      ws = resolve_workspace
      name = ws ? "Quản lý - #{ws.name}" : "Quản lý - Aura"
      theme = ws&.theme_value("primary") || "#1F5FA6"
      bg    = ws&.theme_value("surface") || "#F7F9FC"
      icon_src = if ws&.logo&.attached?
        Rails.application.routes.url_helpers.rails_storage_proxy_path(ws.logo, only_path: true)
      else
        "/icon.png"
      end
      render json: {
        name: name, short_name: name.to_s[0, 30],
        description: "Quản lý spa & massage",
        start_url: "/merchant", scope: "/merchant", display: "standalone",
        background_color: bg, theme_color: theme, lang: "vi",
        icons: [
          { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: icon_src,        sizes: "512x512", type: "image/png", purpose: "any" },
          { src: icon_src,        sizes: "512x512", type: "image/png", purpose: "maskable" }
        ]
      }, content_type: "application/manifest+json"
    end

    private

    def manifest_hash
      ws = @workspace
      app_name = install_name(ws)
      theme = ws&.theme_value("primary") || "#1F5FA6"
      bg    = ws&.theme_value("surface") || "#F7F9FC"
      icon_src = if ws&.logo&.attached?
        Rails.application.routes.url_helpers.rails_storage_proxy_path(ws.logo, only_path: true)
      else
        "/icon.png"
      end
      start = ws ? customer_start_path(ws) : "/"
      {
        name: app_name,
        short_name: app_name.to_s[0, 30],
        description: ws&.branding_value("tagline") || "Quản lý spa & massage",
        start_url: start,
        scope: start,
        display: "standalone",
        background_color: bg,
        theme_color: theme,
        lang: ws&.locale_default || "vi",
        icons: [
          { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: icon_src,        sizes: "512x512", type: "image/png", purpose: "any" },
          { src: icon_src,        sizes: "512x512", type: "image/png", purpose: "maskable" }
        ]
      }
    end

    # Tên cơ sở khách hay tới → nếu không thì tên spa.
    def install_name(ws)
      return "Aura" if ws.nil?
      member = current_member_for(ws)
      member&.home_branch&.name.presence || ws.name
    end

    def current_member_for(ws)
      mid = cookies.signed["mbr_#{ws.id}"]
      return nil if mid.blank?
      Member.where(workspace_id: ws.id).find_by(id: mid)
    rescue StandardError
      nil
    end

    def customer_start_path(ws)
      # In dev/path mode the tenant app lives under /w/:slug.
      Rails.env.production? && ws.subdomain.present? ? "/" : "/w/#{ws.slug}"
    end
  end
end
