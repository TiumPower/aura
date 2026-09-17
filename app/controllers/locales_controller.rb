class LocalesController < ApplicationController
  def update
    locale = params[:locale]
    if I18n.available_locales.map(&:to_s).include?(locale.to_s)
      session[:locale] = locale
      current_member.update(locale: locale) if respond_to?(:current_member) && current_member
      current_user.update(locale: locale) if respond_to?(:current_user) && current_user
    end
    redirect_back fallback_location: "/"
  end
end
