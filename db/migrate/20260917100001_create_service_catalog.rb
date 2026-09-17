# Danh mục dịch vụ + gói/thẻ liệu trình + hàng bán lẻ. Đây là thứ engine xếp
# lịch đọc để biết một lượt khách chiếm phòng loại nào, bao lâu, và có cần KTV
# hay không.
class CreateServiceCatalog < ActiveRecord::Migration[7.2]
  def change
    create_table :service_categories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :icon
      t.string  :color
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index [:workspace_id, :position]
    end

    create_table :services do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :service_category, foreign_key: true
      t.string  :name, null: false
      t.string  :code
      t.string  :slug
      t.text    :description
      t.text    :prep_notes            # KTV cần chuẩn bị gì
      t.text    :contraindications     # ai KHÔNG nên làm dịch vụ này
      t.integer :duration_minutes, null: false, default: 60
      t.integer :buffer_minutes                # dọn dẹp riêng của dịch vụ này
      t.integer :price, null: false, default: 0
      t.integer :cost, null: false, default: 0 # giá vốn ước tính (vật tư)
      t.boolean :requires_room,  null: false, default: true
      t.boolean :requires_staff, null: false, default: true
      t.integer :staff_count, null: false, default: 1   # massage 4 tay = 2 KTV
      t.jsonb   :room_type_ids, null: false, default: []
      t.boolean :is_addon, null: false, default: false  # gắn thêm vào dịch vụ khác
      t.boolean :online_bookable, null: false, default: true
      t.boolean :active, null: false, default: true
      t.boolean :deposit_required, null: false, default: false
      t.integer :deposit_amount
      t.integer :commission_percent            # ghi đè hoa hồng cho dịch vụ này
      t.integer :points_earned                 # ghi đè điểm thưởng
      t.integer :position, null: false, default: 0
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
      t.index [:workspace_id, :active]
      t.index [:workspace_id, :slug]
    end

    # Biến thể thời lượng/giá: "Massage body 60′ / 90′ / 120′" là MỘT dịch vụ với
    # ba biến thể, không phải ba dịch vụ — nếu tách thì báo cáo bị vụn.
    create_table :service_variants do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :service,   null: false, foreign_key: true
      t.string  :name, null: false
      t.integer :duration_minutes, null: false
      t.integer :price, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index [:service_id, :position]
    end

    # Kỹ năng: KTV nào làm được dịch vụ nào. Không khai = engine coi như làm được
    # tất cả (spa nhỏ không muốn khai ma trận kỹ năng ngay ngày đầu).
    create_table :staff_services do |t|
      t.references :workspace,    null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.references :service,      null: false, foreign_key: true
      t.integer :proficiency, null: false, default: 2 # 1 mới, 2 thành thạo, 3 chuyên sâu
      t.timestamps
      t.index [:staff_member_id, :service_id], unique: true, name: "idx_staff_service_unique"
    end

    # Giá riêng theo cơ sở: cùng dịch vụ, chi nhánh trung tâm bán cao hơn.
    create_table :service_prices do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :service,   null: false, foreign_key: true
      t.references :branch,    null: false, foreign_key: true
      t.references :service_variant, foreign_key: true
      t.integer :price, null: false
      t.timestamps
      t.index [:service_id, :branch_id, :service_variant_id], unique: true, name: "idx_service_price_unique"
    end
  end
end
