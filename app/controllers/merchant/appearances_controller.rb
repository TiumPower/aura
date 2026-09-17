module Merchant
  # Spa tự đổi bộ màu, phông chữ, logo và nhận diện của app khách. Đây là phần
  # "white-label": cùng một hệ thống nhưng khách chỉ thấy thương hiệu của spa.
  class AppearancesController < BaseController
    before_action :require_manager!

    def show
      @workspace = current_workspace
      @theme = @workspace.resolved_theme
      @presets = Workspace::THEME_PRESETS
      @fonts = Workspace::FONT_STACKS.keys
    end

    def update
      ws = current_workspace
      theme = ws.theme.presence || {}
      if params[:preset].present? && Workspace::THEME_PRESETS.key?(params[:preset])
        theme = theme.merge(Workspace::THEME_PRESETS[params[:preset]].except("name"))
      end
      %w[primary primary_2 surface surface_2 line radius].each do |k|
        theme[k] = params[k] if params[k].present?
      end
      %w[font_display font_body].each do |k|
        theme[k] = params[k] if params[k].present? && Workspace::FONT_STACKS.key?(params[k])
      end

      branding = (ws.branding || {}).merge(
        params.fetch(:branding, {}).permit(:tagline, :logo_text, :customer_term, :staff_term,
                                           :contact_phone, :zalo, :facebook, :instagram,
                                           :booking_note, :city).to_h.compact_blank
      )
      ws.logo.attach(params[:logo])  if params[:logo].present?
      ws.cover.attach(params[:cover]) if params[:cover].present?
      ws.update!(theme: theme, branding: branding)
      audit!("appearance.update")
      redirect_to merchant_appearance_path, notice: "Đã cập nhật giao diện app khách."
    end

    private

    def nav_key = :appearance
  end
end
