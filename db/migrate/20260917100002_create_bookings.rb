# Lịch hẹn. Một `booking` là một lần khách tới (có thể đi 2–3 người, làm nhiều
# dịch vụ nối nhau); mỗi dòng `booking_item` là MỘT lượt chiếm một phòng và
# (thường là) một KTV trong một khoảng giờ. Tách hai tầng như vậy mới đặt được
# massage đôi (2 item cùng phòng) và chuỗi dịch vụ nối tiếp (body 60′ rồi foot 30′).
class CreateBookings < ActiveRecord::Migration[7.2]
  def change
    create_table :bookings do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.references :member,    foreign_key: true          # nil = khách vãng lai chưa có hồ sơ
      t.string  :code, null: false
      t.string  :guest_name                                # khi chưa có hồ sơ khách
      t.string  :guest_phone
      t.string  :status, null: false, default: "pending"
      # pending → confirmed → checked_in → in_progress → completed
      #                    ↘ cancelled / no_show
      t.string  :source, null: false, default: "staff"     # staff | app | web | phone | walk_in | zalo
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false
      t.integer :party_size, null: false, default: 1
      t.string  :staff_gender_preference
      t.text    :note                                       # khách ghi
      t.text    :internal_note                              # quầy ghi, khách không thấy
      t.integer :estimated_total, null: false, default: 0
      t.integer :deposit_amount,  null: false, default: 0
      t.string  :deposit_state,   null: false, default: "none" # none | pending | paid | refunded | forfeited
      t.datetime :deposit_paid_at
      t.datetime :confirmed_at
      t.datetime :checked_in_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.datetime :no_show_at
      t.string  :cancel_reason
      t.string  :cancelled_by                               # staff | member | system
      t.bigint  :created_by_id                              # User nếu quầy tạo
      t.datetime :reminder_sent_at
      t.datetime :review_requested_at
      t.bigint  :order_id                                   # gắn khi thu ngân đóng bill
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
      t.index [:workspace_id, :code], unique: true
      t.index [:branch_id, :starts_at]
      t.index [:workspace_id, :status]
      t.index [:member_id, :starts_at]
    end

    create_table :booking_items do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :booking,   null: false, foreign_key: true
      t.references :service,   null: false, foreign_key: true
      t.references :service_variant, foreign_key: true
      t.references :staff_member, foreign_key: true          # nil = để spa tự xếp
      t.references :room,         foreign_key: true
      t.bigint  :parent_item_id                              # addon gắn vào lượt nào
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false
      t.integer :duration_minutes, null: false
      t.integer :buffer_minutes, null: false, default: 0
      t.integer :price,           null: false, default: 0
      t.integer :staff_surcharge, null: false, default: 0
      t.integer :discount_amount, null: false, default: 0
      t.string  :guest_label                                 # "Khách 1", "Khách 2"
      t.string  :status, null: false, default: "planned"     # planned | in_progress | done | cancelled
      t.bigint  :package_credit_id                           # trừ buổi từ thẻ liệu trình
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:room_id, :starts_at, :ends_at]
      t.index [:staff_member_id, :starts_at, :ends_at]
      t.index [:workspace_id, :starts_at]
      t.index :parent_item_id
    end

    # Giữ chỗ tạm trong lúc khách đang chọn trên app. Không có bảng này thì hai
    # khách bấm cùng một slot trong cùng 30 giây đều được xác nhận.
    create_table :booking_holds do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.references :room,         foreign_key: true
      t.references :staff_member, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false
      t.string   :token, null: false
      t.datetime :expires_at, null: false
      t.timestamps
      t.index :token, unique: true
      t.index [:branch_id, :starts_at, :ends_at]
      t.index :expires_at
    end
  end
end
