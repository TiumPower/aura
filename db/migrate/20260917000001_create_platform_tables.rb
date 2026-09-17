# Tầng nền tảng dùng chung cho mọi sản phẩm multi-tenant (bê từ Estate/Loyalty):
# super admin, chủ spa + nhân sự có tài khoản, khách hàng đăng nhập PWA, gói
# thuê bao, hoá đơn thuê bao, OTP, push, thông báo, chat.
class CreatePlatformTables < ActiveRecord::Migration[7.2]
  def change
    # ---- Super admin (vận hành nền tảng) --------------------------------
    create_table :admin_users do |t|
      t.string   :name,  null: false, default: ""
      t.string   :role,  null: false, default: "operator"
      t.string   :email, null: false, default: ""
      t.string   :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer  :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.timestamps
      t.index :email, unique: true
      t.index :reset_password_token, unique: true
    end

    # ---- Chủ spa & nhân sự có tài khoản ---------------------------------
    create_table :users do |t|
      t.string   :name,  null: false, default: ""
      t.string   :title
      t.string   :phone
      t.string   :locale, null: false, default: "vi"
      t.string   :email, null: false, default: ""
      t.string   :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer  :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.timestamps
      t.index :email, unique: true
      t.index :reset_password_token, unique: true
    end

    # ---- Workspace = một thương hiệu spa (tenant) -----------------------
    create_table :workspaces do |t|
      t.string   :name, null: false
      t.string   :slug, null: false
      t.string   :subdomain, null: false
      t.string   :custom_domain
      t.datetime :domain_verified_at
      t.string   :status, null: false, default: "trial"
      t.string   :plan,   null: false, default: "starter"
      t.string   :locale_default, null: false, default: "vi"
      t.string   :business_type, null: false, default: "massage" # massage | beauty | mixed
      t.datetime :paid_until
      t.boolean  :auto_renew, null: false, default: false
      t.jsonb    :theme,    null: false, default: {}
      t.jsonb    :branding, null: false, default: {}
      t.jsonb    :settings, null: false, default: {}
      t.timestamps
      t.index :slug,      unique: true
      t.index :subdomain, unique: true
      t.index :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
      t.index :status
    end

    create_table :friendly_id_slugs do |t|
      t.string  :slug, null: false
      t.integer :sluggable_id, null: false
      t.string  :sluggable_type, limit: 50
      t.string  :scope
      t.datetime :created_at
      t.index [:slug, :sluggable_type], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
      t.index [:slug, :sluggable_type, :scope], unique: true,
              name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope"
      t.index [:sluggable_type, :sluggable_id]
    end

    # ---- Gói thuê bao nền tảng ------------------------------------------
    create_table :plans do |t|
      t.string  :key,  null: false
      t.string  :name, null: false
      t.integer :price,    null: false, default: 0
      t.integer :position, null: false, default: 0
      t.integer :max_branches
      t.integer :max_staff
      t.integer :max_rooms
      t.boolean :allow_custom_domain, null: false, default: false
      t.boolean :allow_multi_branch,  null: false, default: false
      t.boolean :allow_packages,      null: false, default: true
      t.boolean :allow_commissions,   null: false, default: true
      t.boolean :allow_inventory,     null: false, default: true
      t.boolean :allow_ai,            null: false, default: true
      t.jsonb   :features, null: false, default: []
      t.timestamps
      t.index :key, unique: true
    end

    create_table :invoices do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :plan,   null: false
      t.integer :amount, null: false, default: 0
      t.string  :status, null: false, default: "pending"
      t.date    :period_start, null: false
      t.date    :period_end,   null: false
      t.bigint  :payos_order_code
      t.string  :checkout_url
      t.datetime :paid_at
      t.jsonb   :gateway_response, null: false, default: {}
      t.timestamps
      t.index [:workspace_id, :status]
      t.index :payos_order_code, unique: true, where: "payos_order_code IS NOT NULL"
    end

    create_table :app_settings do |t|
      t.string :key, null: false
      t.text   :value
      t.timestamps
      t.index :key, unique: true
    end

    # ---- Xác thực bằng OTP (SĐT cho khách, email cho nhân sự) -----------
    create_table :otp_challenges do |t|
      t.references :workspace, foreign_key: true
      t.string   :identifier, null: false           # email hoặc số điện thoại
      t.string   :channel, null: false, default: "email" # email | sms | zalo
      t.string   :scope,   null: false, default: "merchant" # merchant | customer
      t.string   :code,    null: false
      t.string   :purpose, null: false, default: "login"
      t.integer  :attempts, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
      t.index [:scope, :identifier]
      t.index [:workspace_id, :identifier]
    end
  end
end
