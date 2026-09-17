# Lõi vận hành spa: chi nhánh → phòng/giường, nhân sự (KTV/lễ tân), khách hàng,
# ca làm. Mọi bảng nghiệp vụ đều có workspace_id (acts_as_tenant, row-level).
class CreateSpaCore < ActiveRecord::Migration[7.2]
  def change
    # ---- Nhân sự có tài khoản ↔ workspace -------------------------------
    create_table :memberships do |t|
      t.references :user,      null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.bigint  :branch_id                     # nhân sự bị giới hạn 1 chi nhánh
      t.string  :role,   null: false, default: "receptionist"
      t.string  :status, null: false, default: "active"
      t.timestamps
      t.index [:user_id, :workspace_id], unique: true
      t.index :branch_id
    end

    # ---- Chi nhánh -------------------------------------------------------
    create_table :branches do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :code
      t.string  :slug
      t.string  :phone
      t.string  :address_line
      t.string  :ward
      t.string  :district
      t.string  :city
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.text    :description
      t.text    :directions
      t.string  :status, null: false, default: "active"   # active | paused | archived
      t.boolean :online_bookable, null: false, default: true
      t.integer :position, null: false, default: 0
      t.jsonb   :settings, null: false, default: {}       # ghi đè tham số nghiệp vụ
      t.timestamps
      t.index [:workspace_id, :status]
      t.index [:workspace_id, :slug], unique: true
    end

    # Giờ mở cửa theo thứ. Nhiều dòng cùng thứ = ca sáng / ca tối tách nhau.
    create_table :branch_hours do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.integer :weekday, null: false            # 0 = CN … 6 = T7
      t.time    :opens_at
      t.time    :closes_at
      t.boolean :closed, null: false, default: false
      t.timestamps
      t.index [:branch_id, :weekday]
    end

    # Ngày nghỉ / khoảng đóng cửa đột xuất (lễ, bảo trì, nghỉ Tết).
    create_table :branch_closures do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.date    :starts_on, null: false
      t.date    :ends_on,   null: false
      t.time    :starts_at                       # nil = cả ngày
      t.time    :ends_at
      t.string  :reason
      t.timestamps
      t.index [:branch_id, :starts_on]
    end

    # ---- Phòng / giường --------------------------------------------------
    # Loại phòng do từng spa tự định nghĩa (foot, body đơn, đôi, VIP, xông hơi…)
    create_table :room_types do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :key,  null: false
      t.string  :name, null: false
      t.string  :icon
      t.string  :color
      t.integer :default_capacity, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:workspace_id, :key], unique: true
    end

    create_table :rooms do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.references :room_type, foreign_key: true
      t.string  :name, null: false
      t.string  :code
      t.integer :capacity, null: false, default: 1        # số khách phục vụ đồng thời
      t.integer :turnaround_minutes, null: false, default: 10
      t.string  :floor
      t.string  :status, null: false, default: "active"   # active | maintenance | inactive
      t.boolean :online_bookable, null: false, default: true
      t.integer :position, null: false, default: 0
      t.text    :notes
      t.timestamps
      t.index [:branch_id, :status]
    end

    # ---- Nhân sự (KTV, lễ tân, tư vấn) -----------------------------------
    create_table :staff_levels do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :key,  null: false
      t.string  :name, null: false
      t.integer :surcharge, null: false, default: 0       # phụ thu khi khách chọn hạng này
      t.integer :commission_percent
      t.string  :color
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:workspace_id, :key], unique: true
    end

    create_table :staff_members do |t|
      t.references :workspace,   null: false, foreign_key: true
      t.references :branch,      foreign_key: true
      t.references :user,        foreign_key: true        # có tài khoản đăng nhập hay không
      t.references :staff_level, foreign_key: true
      t.string  :code                                     # "số KTV" khách hay gọi
      t.string  :name, null: false
      t.string  :nickname
      t.string  :phone
      t.string  :email
      t.string  :gender
      t.date    :dob
      t.string  :role, null: false, default: "therapist"  # therapist | receptionist | consultant | manager | other
      t.string  :employment_type, null: false, default: "fulltime"
      t.date    :hired_at
      t.date    :left_at
      t.string  :status, null: false, default: "active"   # active | on_leave | inactive
      t.integer :base_salary, null: false, default: 0
      t.integer :commission_percent                       # ghi đè hạng
      t.boolean :online_bookable, null: false, default: true
      t.integer :max_daily_minutes
      t.string  :calendar_color
      t.text    :bio
      t.decimal :rating_avg, precision: 3, scale: 2
      t.integer :rating_count, null: false, default: 0
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
      t.index [:workspace_id, :status]
      t.index [:workspace_id, :code]
    end

    # KTV chạy nhiều chi nhánh
    create_table :staff_branches do |t|
      t.references :workspace,    null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.timestamps
      t.index [:staff_member_id, :branch_id], unique: true, name: "idx_staff_branch_unique"
    end

    # Mẫu ca lặp theo tuần — dùng để sinh ca thật cho từng ngày.
    create_table :shift_templates do |t|
      t.references :workspace,    null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.references :branch,       foreign_key: true
      t.integer :weekday, null: false
      t.time    :starts_at, null: false
      t.time    :ends_at,   null: false
      t.timestamps
      t.index [:staff_member_id, :weekday]
    end

    # Ca làm thật của từng ngày — nguồn duy nhất để biết KTV có rảnh hay không.
    create_table :staff_shifts do |t|
      t.references :workspace,    null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.references :branch,       foreign_key: true
      t.date     :work_date, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false
      t.string   :kind,   null: false, default: "shift" # shift | off | leave | training
      t.string   :status, null: false, default: "scheduled"
      t.string   :note
      t.bigint   :created_by_id
      t.timestamps
      t.index [:workspace_id, :work_date]
      t.index [:staff_member_id, :work_date]
    end

    # ---- Khách hàng ------------------------------------------------------
    # Hạng thành viên do từng spa tự định nghĩa.
    create_table :member_tiers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :key,  null: false
      t.string  :name, null: false
      t.integer :min_spent,  null: false, default: 0
      t.integer :min_visits, null: false, default: 0
      t.integer :discount_percent, null: false, default: 0
      t.decimal :points_multiplier, precision: 4, scale: 2, null: false, default: 1.0
      t.string  :color
      t.jsonb   :perks, null: false, default: []
      t.boolean :auto_assign, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:workspace_id, :key], unique: true
    end

    # Khách hàng. Cùng lúc là bản ghi CRM (lễ tân tạo cho khách walk-in) và tài
    # khoản đăng nhập PWA (SĐT + OTP) — khách walk-in chỉ là bản ghi chưa từng
    # đăng nhập, không phải bảng khác.
    create_table :members do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member_tier, foreign_key: true
      t.bigint  :preferred_staff_id
      t.bigint  :home_branch_id
      t.string  :code
      t.string  :phone, null: false
      t.string  :email
      t.string  :name, null: false, default: ""
      t.string  :gender
      t.date    :dob
      t.integer :dob_day
      t.integer :dob_month
      t.string  :address_line
      t.string  :city
      t.string  :locale, null: false, default: "vi"
      t.string  :source, null: false, default: "walk_in" # walk_in | self_signup | online | import | referral
      t.string  :status, null: false, default: "active"  # active | inactive | blocked
      t.integer :points_balance, null: false, default: 0
      t.integer :wallet_balance, null: false, default: 0 # thẻ tiền / ví trả trước
      t.integer :total_spent,    null: false, default: 0
      t.integer :visits_count,   null: false, default: 0
      t.integer :no_show_count,  null: false, default: 0
      t.integer :cancel_count,   null: false, default: 0
      t.datetime :first_visit_at
      t.datetime :last_visit_at
      t.datetime :blocked_at
      t.string  :blocked_reason
      t.text    :health_notes                            # dị ứng / chống chỉ định
      t.text    :notes
      t.jsonb   :preferences, null: false, default: {}   # áp lực, tinh dầu, giới tính KTV…
      t.jsonb   :tags, null: false, default: []
      t.boolean :marketing_opt_in, null: false, default: true
      t.string  :referral_code
      t.bigint  :referred_by_member_id
      t.string  :encrypted_password, null: false, default: ""
      t.datetime :remember_created_at
      t.datetime :last_seen_at
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
      t.index [:workspace_id, :phone], unique: true
      t.index [:workspace_id, :email], where: "email IS NOT NULL"
      t.index [:workspace_id, :status]
      t.index [:workspace_id, :code], unique: true, where: "code IS NOT NULL"
      t.index :preferred_staff_id
    end

    add_foreign_key :memberships, :branches, column: :branch_id
    add_foreign_key :members, :staff_members, column: :preferred_staff_id
    add_foreign_key :members, :branches,      column: :home_branch_id

    # ---- Hạ tầng phụ trợ -------------------------------------------------
    create_table :push_subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member, foreign_key: true
      t.references :user,   foreign_key: true
      t.string :endpoint, null: false
      t.string :p256dh,   null: false
      t.string :auth,     null: false
      t.timestamps
      t.index [:member_id, :endpoint], unique: true
    end

    create_table :broadcasts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint  :created_by_id
      t.string  :segment_key, null: false, default: "all"
      t.string  :title, null: false
      t.text    :body
      t.integer :sent_count, null: false, default: 0
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.timestamps
      t.index :created_by_id
    end

    create_table :notifications do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member,    null: false, foreign_key: true
      t.references :broadcast, foreign_key: true
      t.string  :title, null: false
      t.text    :body
      t.string  :kind, null: false, default: "system"
      t.string  :icon
      t.string  :deep_link
      t.datetime :read_at
      t.timestamps
      t.index [:member_id, :created_at]
      t.index [:member_id, :read_at]
    end

    create_table :conversations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member,    null: false, foreign_key: true
      t.datetime :last_message_at
      t.integer  :staff_unread,  null: false, default: 0
      t.integer  :member_unread, null: false, default: 0
      t.timestamps
      t.index [:workspace_id, :member_id], unique: true
    end

    create_table :messages do |t|
      t.references :workspace,    null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.string  :sender_kind, null: false
      t.bigint  :sender_user_id
      t.bigint  :sender_member_id
      t.string  :sender_name
      t.text    :body, null: false
      t.timestamps
      t.index [:conversation_id, :created_at]
    end

    # Chi phí vận hành (tiền ra) — ghép với doanh thu để ra lãi thật.
    create_table :expenses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    foreign_key: true
      t.string  :category, null: false, default: "other"
      t.string  :note
      t.integer :amount, null: false, default: 0
      t.date    :spent_on, null: false
      t.string  :vendor
      t.timestamps
      t.index [:workspace_id, :spent_on]
      t.index [:workspace_id, :category]
    end

    # Nhật ký thao tác — mọi thao tác ghi đều để lại dấu.
    create_table :audit_logs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :actor_type
      t.bigint  :actor_id
      t.string  :actor_name
      t.string  :action, null: false
      t.string  :target_type
      t.bigint  :target_id
      t.string  :summary
      t.jsonb   :payload, null: false, default: {}
      t.string  :ip
      t.datetime :created_at, null: false
      t.index [:workspace_id, :created_at]
      t.index [:target_type, :target_id]
    end
  end
end
