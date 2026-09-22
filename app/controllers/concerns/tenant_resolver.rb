# Xác định Workspace (spa) cho app khách, theo thứ tự:
#   1. đoạn đường dẫn /w/:workspace_slug (dự phòng cho dev)
#   2. tên miền riêng của spa (VD: booking.auraspa.vn)
#   3. subdomain của spa      (VD: auraspa.aura.tiumpower.com / auraspa.lvh.me)
# Các subdomain dành riêng (app, admin, www, api) không bao giờ là một spa.
module TenantResolver
  extend ActiveSupport::Concern

  RESERVED_SUBDOMAINS = %w[app admin www api assets].freeze

  private

  def resolve_workspace
    by_slug || by_custom_domain || by_subdomain
  end

  # /w/:x nhận CẢ slug lẫn subdomain. Slug của "Aura Spa Sài Gòn" là
  # aura-spa-sai-gon còn subdomain là auraspa — bắt người dùng nhớ đúng một
  # trong hai chuỗi chỉ tổ sinh ra 404.
  def by_slug
    key = params[:workspace_slug]
    return nil if key.blank?
    Workspace.friendly.find_by(slug: key) || Workspace.find_by(subdomain: key)
  end

  def by_custom_domain
    Workspace.find_by(custom_domain: request.host)
  end

  def by_subdomain
    sub = request.subdomains.first
    return nil if sub.blank? || RESERVED_SUBDOMAINS.include?(sub)
    Workspace.find_by(subdomain: sub)
  end
end
