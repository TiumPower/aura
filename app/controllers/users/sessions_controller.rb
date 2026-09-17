module Users
  # Merchant (User scope) login. Overrides only the post-login redirect so it
  # may hop to the owner's workspace subdomain (after_sign_in_path_for returns
  # an absolute subdomain URL in production).
  class SessionsController < Devise::SessionsController
    protected

    def respond_with(resource, _opts = {})
      if resource.persisted?
        redirect_to after_sign_in_path_for(resource), allow_other_host: true
      else
        super
      end
    end
  end
end
