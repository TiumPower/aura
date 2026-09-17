# Tiền: bill tại quầy, thẻ liệu trình (gói nhiều buổi), ví trả trước, điểm
# thưởng và hoa hồng. Tách rõ hai loại "hoá đơn":
#   Order   — spa thu tiền của KHÁCH
#   Invoice — nền tảng thu tiền thuê bao của SPA (đã có từ P0)
class CreatePosAndPackages < ActiveRecord::Migration[7.2]
  def change
    # ---- Gói / thẻ liệu trình (định nghĩa để bán) ------------------------
    create_table :packages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :kind, null: false, default: "session_pack" # session_pack | value_card | membership
      t.text    :description
      t.integer :price, null: false, default: 0
      t.integer :face_value                          # thẻ tiền: nạp 5tr dùng được 6tr
      t.integer :validity_days
      t.boolean :transferable, null: false, default: false
      t.boolean :family_share, null: false, default: false
      t.boolean :online_sellable, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :commission_percent                  # hoa hồng cho người chốt thẻ
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:workspace_id, :active]
    end

    # Gói gồm những gì: mỗi dòng là "n buổi dịch vụ X".
    create_table :package_lines do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :package,   null: false, foreign_key: true
      t.references :service,   null: false, foreign_key: true
      t.references :service_variant, foreign_key: true
      t.integer :sessions, null: false, default: 1
      t.timestamps
      t.index [:package_id, :service_id]
    end

    # ---- Bill tại quầy ----------------------------------------------------
    create_table :orders do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.references :member,    foreign_key: true
      t.bigint  :booking_id
      t.string  :code, null: false
      t.string  :status, null: false, default: "open"  # open | paid | void | refunded
      t.integer :subtotal,       null: false, default: 0
      t.integer :discount_total, null: false, default: 0
      t.integer :service_charge, null: false, default: 0
      t.integer :vat_total,      null: false, default: 0
      t.integer :tip_total,      null: false, default: 0
      t.integer :total,          null: false, default: 0
      t.integer :paid_total,     null: false, default: 0
      t.integer :points_earned,  null: false, default: 0
      t.integer :points_redeemed, null: false, default: 0
      t.string  :discount_note
      t.text    :note
      t.bigint  :cashier_id
      t.bigint  :voided_by_id
      t.datetime :closed_at
      t.datetime :voided_at
      t.string  :void_reason
      t.timestamps
      t.index [:workspace_id, :code], unique: true
      t.index [:branch_id, :closed_at]
      t.index [:workspace_id, :status]
      t.index :booking_id
      t.index [:member_id, :closed_at]
    end

    create_table :order_items do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :order,     null: false, foreign_key: true
      t.string  :kind, null: false, default: "service" # service | addon | package | topup | product | fee | tip
      t.bigint  :service_id
      t.bigint  :package_id
      t.bigint  :booking_item_id
      t.bigint  :staff_member_id      # KTV thực hiện → hoa hồng làm dịch vụ
      t.bigint  :consultant_id        # người chốt thẻ  → hoa hồng tư vấn
      t.bigint  :package_credit_id    # trừ buổi từ thẻ → tiền dòng này = 0
      t.string  :name, null: false    # chốt tên lúc bán, không đổi khi sửa danh mục
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price, null: false, default: 0
      t.integer :discount_amount, null: false, default: 0
      t.integer :total, null: false, default: 0
      t.integer :commission_amount, null: false, default: 0
      t.jsonb   :meta, null: false, default: {}
      t.timestamps
      t.index [:staff_member_id, :created_at]
      t.index :booking_item_id
    end

    create_table :order_payments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :order,     null: false, foreign_key: true
      t.string  :method, null: false            # cash | card | transfer | vietqr | wallet | package | points | other
      t.integer :amount, null: false, default: 0
      t.string  :reference
      t.bigint  :received_by_id
      t.datetime :received_at, null: false
      t.text    :note
      t.timestamps
      t.index [:workspace_id, :received_at]
      t.index [:order_id, :method]
    end

    # ---- Thẻ khách đã mua -------------------------------------------------
    create_table :member_packages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member,    null: false, foreign_key: true
      t.references :package,   foreign_key: true
      t.bigint  :order_id
      t.bigint  :sold_by_id                        # nhân sự chốt thẻ
      t.string  :name, null: false                 # chốt tên lúc bán
      t.string  :kind, null: false, default: "session_pack"
      t.string  :status, null: false, default: "active" # active | used_up | expired | frozen | refunded
      t.integer :price_paid, null: false, default: 0
      t.integer :value_balance, null: false, default: 0 # thẻ tiền còn lại
      t.date    :purchased_on, null: false
      t.date    :expires_on
      t.datetime :frozen_at
      t.text    :note
      t.timestamps
      t.index [:member_id, :status]
      t.index [:workspace_id, :expires_on]
    end

    # Số buổi còn lại theo từng dịch vụ trong một thẻ.
    create_table :package_credits do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member_package, null: false, foreign_key: true
      t.references :service,   null: false, foreign_key: true
      t.references :service_variant, foreign_key: true
      t.integer :total_sessions, null: false, default: 0
      t.integer :used_sessions,  null: false, default: 0
      t.timestamps
      t.index [:member_package_id, :service_id], name: "idx_credit_pkg_service"
    end

    # Mỗi lần trừ buổi để lại dấu — tranh chấp "sao hết buổi rồi" là chuyện
    # thường xuyên nhất giữa spa và khách.
    create_table :package_credit_uses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :package_credit, null: false, foreign_key: true
      t.bigint  :booking_item_id
      t.bigint  :order_item_id
      t.bigint  :staff_member_id
      t.integer :sessions, null: false, default: 1   # âm = hoàn buổi
      t.string  :reason
      t.bigint  :actor_id
      t.datetime :used_at, null: false
      t.timestamps
      t.index [:package_credit_id, :used_at]
    end

    # ---- Ví trả trước -----------------------------------------------------
    create_table :wallet_transactions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member,    null: false, foreign_key: true
      t.bigint  :order_id
      t.string  :kind, null: false            # topup | bonus | spend | refund | adjust
      t.integer :amount, null: false          # âm = trừ
      t.integer :balance_after, null: false, default: 0
      t.string  :note
      t.bigint  :actor_id
      t.timestamps
      t.index [:member_id, :created_at]
    end

    # ---- Điểm thưởng ------------------------------------------------------
    create_table :point_transactions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :member,    null: false, foreign_key: true
      t.bigint  :order_id
      t.string  :kind, null: false            # earn | redeem | expire | adjust
      t.integer :points, null: false
      t.integer :balance_after, null: false, default: 0
      t.string  :note
      t.bigint  :actor_id
      t.datetime :expires_on
      t.timestamps
      t.index [:member_id, :created_at]
    end

    # ---- Hoa hồng ---------------------------------------------------------
    create_table :commission_entries do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.bigint  :order_id
      t.bigint  :order_item_id
      t.string  :role, null: false, default: "therapist" # therapist | consultant
      t.string  :basis, null: false, default: "percent"  # percent | fixed | tip
      t.integer :base_amount, null: false, default: 0
      t.integer :rate, null: false, default: 0
      t.integer :amount, null: false, default: 0
      t.date    :earned_on, null: false
      t.string  :status, null: false, default: "pending" # pending | approved | paid
      t.timestamps
      t.index [:staff_member_id, :earned_on]
      t.index [:workspace_id, :earned_on]
      t.index :order_item_id
    end

    add_foreign_key :orders, :bookings, column: :booking_id
    add_foreign_key :order_items, :orders, column: :order_id unless foreign_key_exists?(:order_items, :orders)
  end
end
