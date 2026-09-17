Rails.application.routes.draw do
  # ---- Devise mappings ---------------------------------------------------
  # Nhân sự (User) đăng nhập bằng email + OTP, khách (Member) bằng SĐT + OTP,
  # cả hai qua controller riêng — Devise chỉ để lại phần session của Warden.
  # Super admin vẫn dùng mật khẩu của Devise.
  devise_for :users, skip: :all
  devise_for :members, skip: :all
  devise_for :admin_users,
             path: "admin",
             path_names: { sign_in: "login", sign_out: "logout", password: "password" },
             skip: [:registrations]

  # ---- Webhook PayOS (không CSRF) ----------------------------------------
  post "webhooks/payos" => "webhooks/payos#receive", as: :payos_webhook

  # ---- PWA (theo từng workspace, sinh động) ------------------------------
  get "manifest.webmanifest" => "pwa/manifests#show",       as: :pwa_manifest
  get "service-worker.js"    => "pwa/service_workers#show", as: :pwa_service_worker

  # ---- Đổi ngôn ngữ -------------------------------------------------------
  get "/set_locale/:locale", to: "locales#update", as: :set_locale

  # ---- Super Admin (vận hành nền tảng) : /admin --------------------------
  namespace :admin do
    root "dashboard#show"
    resources :workspaces, only: [:index, :new, :create, :show, :update, :destroy] do
      member do
        patch :approve
        patch :suspend
        patch :reactivate
        post  :impersonate
      end
    end
    get "billing",    to: "billing#show"
    resources :plans, only: [:index, :update]
    get   "account", to: "account#edit",   as: :account
    patch "account", to: "account#update"
  end

  # ---- Cổng nhân sự: đăng nhập -------------------------------------------
  get  "/merchant/signup", to: "merchant/signups#new", as: :merchant_signup
  post "/merchant/signup", to: "merchant/signups#create"
  get    "/merchant/login",  to: "merchant/sessions#new",    as: :merchant_login
  post   "/merchant/login",  to: "merchant/sessions#create"
  get    "/merchant/qr-login/:token", to: "merchant/sessions#qr_login", as: :merchant_qr_login
  get    "/merchant/manifest.webmanifest", to: "pwa/manifests#merchant", as: :merchant_manifest
  post   "/merchant/push/subscribe",   to: "merchant/push#subscribe",   as: :merchant_push_subscribe
  post   "/merchant/push/unsubscribe", to: "merchant/push#unsubscribe", as: :merchant_push_unsubscribe
  get    "/merchant/verify", to: "merchant/sessions#verify_form", as: :merchant_verify
  post   "/merchant/verify", to: "merchant/sessions#verify",      as: :merchant_verify_submit
  delete "/merchant/logout", to: "merchant/sessions#destroy",     as: :merchant_logout
  delete "/merchant/stop-impersonation", to: "merchant/sessions#stop_impersonation", as: :merchant_stop_impersonation

  # ---- Cổng quản lý spa : /merchant --------------------------------------
  namespace :merchant do
    root "dashboard#show"
    resource :account, only: [:show, :update], controller: "account"
    get   "onboarding",      to: "onboarding#show",   as: :onboarding
    patch "onboarding",      to: "onboarding#update"
    post  "onboarding/skip", to: "onboarding#skip",   as: :skip_onboarding
    post  "switch_workspace/:id", to: "workspaces#switch", as: :switch_workspace
    post  "switch_branch/:id",    to: "workspaces#switch_branch", as: :switch_branch

    # ---- Cơ sở, phòng, giường -------------------------------------------
    resources :branches do
      member { patch :archive }
      resources :rooms, only: [:new, :create]
      resources :branch_hours, path: "hours", only: [:index, :create] do
        collection { patch :bulk_update }
      end
      resources :branch_closures, path: "closures", only: [:create, :destroy]
    end
    resources :rooms, only: [:index, :show, :edit, :update, :destroy] do
      member { patch :status }
    end
    resources :room_types, path: "room-types", except: [:show] do
      collection { post :seed_presets }
    end

    # ---- Nhân sự ----------------------------------------------------------
    resources :staff, controller: "staff_members", except: [:destroy] do
      member do
        patch :archive
        patch :reactivate
      end
      resources :shift_templates, path: "shift-templates", only: [:create, :destroy]
    end
    resources :staff_levels, path: "levels", except: [:show] do
      collection { post :seed_presets }
    end
    # Bảng ca làm: một màn hình một tuần, kéo cả cơ sở
    get  "shifts",          to: "shifts#index",    as: :shifts
    post "shifts",          to: "shifts#create"
    post "shifts/generate", to: "shifts#generate", as: :generate_shifts
    delete "shifts/:id",    to: "shifts#destroy",  as: :shift

    # ---- Khách hàng -------------------------------------------------------
    resources :customers, controller: "customers" do
      member do
        patch :block
        patch :unblock
        patch :preferences
      end
    end
    resources :member_tiers, path: "tiers", except: [:show] do
      collection { post :seed_presets }
    end

    # ---- Tiền ra ----------------------------------------------------------
    resources :expenses, except: [:show]

    # ---- Thiết lập --------------------------------------------------------
    get   "settings",          to: "settings#show",          as: :settings
    patch "settings",          to: "settings#update"
    get   "settings/modules",  to: "settings#modules",       as: :settings_modules
    patch "settings/modules",  to: "settings#update_modules"
    resource :appearance, only: [:show, :update], controller: "appearances"
    get   "payment", to: "payment_settings#show",   as: :payment_settings
    patch "payment", to: "payment_settings#update"

    # ---- Chat & thông báo --------------------------------------------------
    get "customers/:customer_id/chat", to: "conversations#for_customer", as: :customer_chat
    get  "announcements/new", to: "announcements#new",    as: :new_announcement
    post "announcements",      to: "announcements#create", as: :announcements
    resources :conversations, path: "chat", only: [:index, :show] do
      member { delete :clear }
      resources :messages, only: [:create, :update, :destroy]
    end

    # ---- Nhật ký thao tác ---------------------------------------------------
    get "audit", to: "audit_logs#index", as: :audit_logs

    # ---- Thuê bao nền tảng ---------------------------------------------------
    resource  :billing, only: [:show], controller: "billing"
    post  "billing/pay",        to: "subscription#create",     as: :billing_pay
    post  "billing/repay/:id",  to: "subscription#repay",      as: :billing_repay
    get   "billing/return",     to: "subscription#return",     as: :billing_return
    patch "billing/auto_renew", to: "subscription#auto_renew", as: :billing_auto_renew
  end

  # ---- App khách: subdomain của spa / tên miền riêng, hoặc /w/:slug -------
  # Đăng nhập đặt ở "/vao" chứ không phải "/login": segment (/w/:slug) là tuỳ
  # chọn nên ở chế độ subdomain "login" rút thành đúng /login và đụng route
  # đăng nhập của nhân sự khai phía trên.
  scope "(/w/:workspace_slug)", module: :customer, as: :member do
    get "", to: "home#show", as: :root
    get    "vao",    to: "sessions#new",         as: :login
    post   "vao",    to: "sessions#create"
    get    "xac-thuc", to: "sessions#verify_form", as: :verify
    post   "xac-thuc", to: "sessions#verify",      as: :verify_submit
    delete "logout", to: "sessions#destroy",     as: :logout

    post "push/subscribe",   to: "push#subscribe",   as: :push_subscribe
    post "push/unsubscribe", to: "push#unsubscribe", as: :push_unsubscribe

    get  "notifications", to: "notifications#index", as: :notifications
    post "notifications/read_all", to: "notifications#read_all", as: :read_all_notifications

    get  "chat",          to: "chat#show",    as: :chat
    get  "chat/updates",  to: "chat#updates", as: :chat_updates
    post   "chat/messages",     to: "chat#create_message", as: :chat_messages
    patch  "chat/messages/:id", to: "chat#update_message", as: :chat_message
    delete "chat/messages/:id", to: "chat#destroy_message"

    get   "toi", to: "profile#show", as: :profile
    patch "toi", to: "profile#update"
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Host trần → app khách (hiện bảng chọn spa khi chưa xác định được workspace).
  root "customer/home#show"
end
