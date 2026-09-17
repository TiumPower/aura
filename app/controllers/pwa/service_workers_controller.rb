module Pwa
  class ServiceWorkersController < ApplicationController
    # The SW is fetched by navigator.serviceWorker.register, not a <script> tag;
    # Rails' cross-origin JS guard (InvalidCrossOriginRequest → 422) must not apply.
    skip_forgery_protection
    skip_before_action :set_locale, raise: false

    def show
      render template: "pwa/service_worker", layout: false,
             content_type: "text/javascript"
    end
  end
end
