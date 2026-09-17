# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_09_17_100002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "role", default: "operator", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "actor_type"
    t.bigint "actor_id"
    t.string "actor_name"
    t.string "action", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.string "summary"
    t.jsonb "payload", default: {}, null: false
    t.string "ip"
    t.datetime "created_at", null: false
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
    t.index ["workspace_id", "created_at"], name: "index_audit_logs_on_workspace_id_and_created_at"
    t.index ["workspace_id"], name: "index_audit_logs_on_workspace_id"
  end

  create_table "booking_holds", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "room_id"
    t.bigint "staff_member_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "starts_at", "ends_at"], name: "index_booking_holds_on_branch_id_and_starts_at_and_ends_at"
    t.index ["branch_id"], name: "index_booking_holds_on_branch_id"
    t.index ["expires_at"], name: "index_booking_holds_on_expires_at"
    t.index ["room_id"], name: "index_booking_holds_on_room_id"
    t.index ["staff_member_id"], name: "index_booking_holds_on_staff_member_id"
    t.index ["token"], name: "index_booking_holds_on_token", unique: true
    t.index ["workspace_id"], name: "index_booking_holds_on_workspace_id"
  end

  create_table "booking_items", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "booking_id", null: false
    t.bigint "service_id", null: false
    t.bigint "service_variant_id"
    t.bigint "staff_member_id"
    t.bigint "room_id"
    t.bigint "parent_item_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.integer "duration_minutes", null: false
    t.integer "buffer_minutes", default: 0, null: false
    t.integer "price", default: 0, null: false
    t.integer "staff_surcharge", default: 0, null: false
    t.integer "discount_amount", default: 0, null: false
    t.string "guest_label"
    t.string "status", default: "planned", null: false
    t.bigint "package_credit_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_booking_items_on_booking_id"
    t.index ["parent_item_id"], name: "index_booking_items_on_parent_item_id"
    t.index ["room_id", "starts_at", "ends_at"], name: "index_booking_items_on_room_id_and_starts_at_and_ends_at"
    t.index ["room_id"], name: "index_booking_items_on_room_id"
    t.index ["service_id"], name: "index_booking_items_on_service_id"
    t.index ["service_variant_id"], name: "index_booking_items_on_service_variant_id"
    t.index ["staff_member_id", "starts_at", "ends_at"], name: "idx_on_staff_member_id_starts_at_ends_at_98085d8f21"
    t.index ["staff_member_id"], name: "index_booking_items_on_staff_member_id"
    t.index ["workspace_id", "starts_at"], name: "index_booking_items_on_workspace_id_and_starts_at"
    t.index ["workspace_id"], name: "index_booking_items_on_workspace_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "member_id"
    t.string "code", null: false
    t.string "guest_name"
    t.string "guest_phone"
    t.string "status", default: "pending", null: false
    t.string "source", default: "staff", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.integer "party_size", default: 1, null: false
    t.string "staff_gender_preference"
    t.text "note"
    t.text "internal_note"
    t.integer "estimated_total", default: 0, null: false
    t.integer "deposit_amount", default: 0, null: false
    t.string "deposit_state", default: "none", null: false
    t.datetime "deposit_paid_at"
    t.datetime "confirmed_at"
    t.datetime "checked_in_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.datetime "no_show_at"
    t.string "cancel_reason"
    t.string "cancelled_by"
    t.bigint "created_by_id"
    t.datetime "reminder_sent_at"
    t.datetime "review_requested_at"
    t.bigint "order_id"
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "starts_at"], name: "index_bookings_on_branch_id_and_starts_at"
    t.index ["branch_id"], name: "index_bookings_on_branch_id"
    t.index ["member_id", "starts_at"], name: "index_bookings_on_member_id_and_starts_at"
    t.index ["member_id"], name: "index_bookings_on_member_id"
    t.index ["workspace_id", "code"], name: "index_bookings_on_workspace_id_and_code", unique: true
    t.index ["workspace_id", "status"], name: "index_bookings_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_bookings_on_workspace_id"
  end

  create_table "branch_closures", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.time "starts_at"
    t.time "ends_at"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "starts_on"], name: "index_branch_closures_on_branch_id_and_starts_on"
    t.index ["branch_id"], name: "index_branch_closures_on_branch_id"
    t.index ["workspace_id"], name: "index_branch_closures_on_workspace_id"
  end

  create_table "branch_hours", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id", null: false
    t.integer "weekday", null: false
    t.time "opens_at"
    t.time "closes_at"
    t.boolean "closed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "weekday"], name: "index_branch_hours_on_branch_id_and_weekday"
    t.index ["branch_id"], name: "index_branch_hours_on_branch_id"
    t.index ["workspace_id"], name: "index_branch_hours_on_workspace_id"
  end

  create_table "branches", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "code"
    t.string "slug"
    t.string "phone"
    t.string "address_line"
    t.string "ward"
    t.string "district"
    t.string "city"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.text "description"
    t.text "directions"
    t.string "status", default: "active", null: false
    t.boolean "online_bookable", default: true, null: false
    t.integer "position", default: 0, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "slug"], name: "index_branches_on_workspace_id_and_slug", unique: true
    t.index ["workspace_id", "status"], name: "index_branches_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_branches_on_workspace_id"
  end

  create_table "broadcasts", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "created_by_id"
    t.string "segment_key", default: "all", null: false
    t.string "title", null: false
    t.text "body"
    t.integer "sent_count", default: 0, null: false
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_broadcasts_on_created_by_id"
    t.index ["workspace_id"], name: "index_broadcasts_on_workspace_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "member_id", null: false
    t.datetime "last_message_at"
    t.integer "staff_unread", default: 0, null: false
    t.integer "member_unread", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_conversations_on_member_id"
    t.index ["workspace_id", "member_id"], name: "index_conversations_on_workspace_id_and_member_id", unique: true
    t.index ["workspace_id"], name: "index_conversations_on_workspace_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id"
    t.string "category", default: "other", null: false
    t.string "note"
    t.integer "amount", default: 0, null: false
    t.date "spent_on", null: false
    t.string "vendor"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_expenses_on_branch_id"
    t.index ["workspace_id", "category"], name: "index_expenses_on_workspace_id_and_category"
    t.index ["workspace_id", "spent_on"], name: "index_expenses_on_workspace_id_and_spent_on"
    t.index ["workspace_id"], name: "index_expenses_on_workspace_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "plan", null: false
    t.integer "amount", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.bigint "payos_order_code"
    t.string "checkout_url"
    t.datetime "paid_at"
    t.jsonb "gateway_response", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payos_order_code"], name: "index_invoices_on_payos_order_code", unique: true, where: "(payos_order_code IS NOT NULL)"
    t.index ["workspace_id", "status"], name: "index_invoices_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_invoices_on_workspace_id"
  end

  create_table "member_tiers", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "min_spent", default: 0, null: false
    t.integer "min_visits", default: 0, null: false
    t.integer "discount_percent", default: 0, null: false
    t.decimal "points_multiplier", precision: 4, scale: 2, default: "1.0", null: false
    t.string "color"
    t.jsonb "perks", default: [], null: false
    t.boolean "auto_assign", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "key"], name: "index_member_tiers_on_workspace_id_and_key", unique: true
    t.index ["workspace_id"], name: "index_member_tiers_on_workspace_id"
  end

  create_table "members", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "member_tier_id"
    t.bigint "preferred_staff_id"
    t.bigint "home_branch_id"
    t.string "code"
    t.string "phone", null: false
    t.string "email"
    t.string "name", default: "", null: false
    t.string "gender"
    t.date "dob"
    t.integer "dob_day"
    t.integer "dob_month"
    t.string "address_line"
    t.string "city"
    t.string "locale", default: "vi", null: false
    t.string "source", default: "walk_in", null: false
    t.string "status", default: "active", null: false
    t.integer "points_balance", default: 0, null: false
    t.integer "wallet_balance", default: 0, null: false
    t.integer "total_spent", default: 0, null: false
    t.integer "visits_count", default: 0, null: false
    t.integer "no_show_count", default: 0, null: false
    t.integer "cancel_count", default: 0, null: false
    t.datetime "first_visit_at"
    t.datetime "last_visit_at"
    t.datetime "blocked_at"
    t.string "blocked_reason"
    t.text "health_notes"
    t.text "notes"
    t.jsonb "preferences", default: {}, null: false
    t.jsonb "tags", default: [], null: false
    t.boolean "marketing_opt_in", default: true, null: false
    t.string "referral_code"
    t.bigint "referred_by_member_id"
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "last_seen_at"
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_tier_id"], name: "index_members_on_member_tier_id"
    t.index ["preferred_staff_id"], name: "index_members_on_preferred_staff_id"
    t.index ["workspace_id", "code"], name: "index_members_on_workspace_id_and_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["workspace_id", "email"], name: "index_members_on_workspace_id_and_email", where: "(email IS NOT NULL)"
    t.index ["workspace_id", "phone"], name: "index_members_on_workspace_id_and_phone", unique: true
    t.index ["workspace_id", "status"], name: "index_members_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_members_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.bigint "branch_id"
    t.string "role", default: "receptionist", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_memberships_on_branch_id"
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "conversation_id", null: false
    t.string "sender_kind", null: false
    t.bigint "sender_user_id"
    t.bigint "sender_member_id"
    t.string "sender_name"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["workspace_id"], name: "index_messages_on_workspace_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "member_id", null: false
    t.bigint "broadcast_id"
    t.string "title", null: false
    t.text "body"
    t.string "kind", default: "system", null: false
    t.string "icon"
    t.string "deep_link"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["broadcast_id"], name: "index_notifications_on_broadcast_id"
    t.index ["member_id", "created_at"], name: "index_notifications_on_member_id_and_created_at"
    t.index ["member_id", "read_at"], name: "index_notifications_on_member_id_and_read_at"
    t.index ["member_id"], name: "index_notifications_on_member_id"
    t.index ["workspace_id"], name: "index_notifications_on_workspace_id"
  end

  create_table "otp_challenges", force: :cascade do |t|
    t.bigint "workspace_id"
    t.string "identifier", null: false
    t.string "channel", default: "email", null: false
    t.string "scope", default: "merchant", null: false
    t.string "code", null: false
    t.string "purpose", default: "login", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scope", "identifier"], name: "index_otp_challenges_on_scope_and_identifier"
    t.index ["workspace_id", "identifier"], name: "index_otp_challenges_on_workspace_id_and_identifier"
    t.index ["workspace_id"], name: "index_otp_challenges_on_workspace_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.integer "price", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.integer "max_branches"
    t.integer "max_staff"
    t.integer "max_rooms"
    t.boolean "allow_custom_domain", default: false, null: false
    t.boolean "allow_multi_branch", default: false, null: false
    t.boolean "allow_packages", default: true, null: false
    t.boolean "allow_commissions", default: true, null: false
    t.boolean "allow_inventory", default: true, null: false
    t.boolean "allow_ai", default: true, null: false
    t.jsonb "features", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_plans_on_key", unique: true
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "member_id"
    t.bigint "user_id"
    t.string "endpoint", null: false
    t.string "p256dh", null: false
    t.string "auth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id", "endpoint"], name: "index_push_subscriptions_on_member_id_and_endpoint", unique: true
    t.index ["member_id"], name: "index_push_subscriptions_on_member_id"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
    t.index ["workspace_id"], name: "index_push_subscriptions_on_workspace_id"
  end

  create_table "room_types", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "icon"
    t.string "color"
    t.integer "default_capacity", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "key"], name: "index_room_types_on_workspace_id_and_key", unique: true
    t.index ["workspace_id"], name: "index_room_types_on_workspace_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "room_type_id"
    t.string "name", null: false
    t.string "code"
    t.integer "capacity", default: 1, null: false
    t.integer "turnaround_minutes", default: 10, null: false
    t.string "floor"
    t.string "status", default: "active", null: false
    t.boolean "online_bookable", default: true, null: false
    t.integer "position", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "status"], name: "index_rooms_on_branch_id_and_status"
    t.index ["branch_id"], name: "index_rooms_on_branch_id"
    t.index ["room_type_id"], name: "index_rooms_on_room_type_id"
    t.index ["workspace_id"], name: "index_rooms_on_workspace_id"
  end

  create_table "service_categories", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "icon"
    t.string "color"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "position"], name: "index_service_categories_on_workspace_id_and_position"
    t.index ["workspace_id"], name: "index_service_categories_on_workspace_id"
  end

  create_table "service_prices", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "service_id", null: false
    t.bigint "branch_id", null: false
    t.bigint "service_variant_id"
    t.integer "price", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_service_prices_on_branch_id"
    t.index ["service_id", "branch_id", "service_variant_id"], name: "idx_service_price_unique", unique: true
    t.index ["service_id"], name: "index_service_prices_on_service_id"
    t.index ["service_variant_id"], name: "index_service_prices_on_service_variant_id"
    t.index ["workspace_id"], name: "index_service_prices_on_workspace_id"
  end

  create_table "service_variants", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "service_id", null: false
    t.string "name", null: false
    t.integer "duration_minutes", null: false
    t.integer "price", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id", "position"], name: "index_service_variants_on_service_id_and_position"
    t.index ["service_id"], name: "index_service_variants_on_service_id"
    t.index ["workspace_id"], name: "index_service_variants_on_workspace_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "service_category_id"
    t.string "name", null: false
    t.string "code"
    t.string "slug"
    t.text "description"
    t.text "prep_notes"
    t.text "contraindications"
    t.integer "duration_minutes", default: 60, null: false
    t.integer "buffer_minutes"
    t.integer "price", default: 0, null: false
    t.integer "cost", default: 0, null: false
    t.boolean "requires_room", default: true, null: false
    t.boolean "requires_staff", default: true, null: false
    t.integer "staff_count", default: 1, null: false
    t.jsonb "room_type_ids", default: [], null: false
    t.boolean "is_addon", default: false, null: false
    t.boolean "online_bookable", default: true, null: false
    t.boolean "active", default: true, null: false
    t.boolean "deposit_required", default: false, null: false
    t.integer "deposit_amount"
    t.integer "commission_percent"
    t.integer "points_earned"
    t.integer "position", default: 0, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_category_id"], name: "index_services_on_service_category_id"
    t.index ["workspace_id", "active"], name: "index_services_on_workspace_id_and_active"
    t.index ["workspace_id", "slug"], name: "index_services_on_workspace_id_and_slug"
    t.index ["workspace_id"], name: "index_services_on_workspace_id"
  end

  create_table "shift_templates", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "staff_member_id", null: false
    t.bigint "branch_id"
    t.integer "weekday", null: false
    t.time "starts_at", null: false
    t.time "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_shift_templates_on_branch_id"
    t.index ["staff_member_id", "weekday"], name: "index_shift_templates_on_staff_member_id_and_weekday"
    t.index ["staff_member_id"], name: "index_shift_templates_on_staff_member_id"
    t.index ["workspace_id"], name: "index_shift_templates_on_workspace_id"
  end

  create_table "staff_branches", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "staff_member_id", null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_staff_branches_on_branch_id"
    t.index ["staff_member_id", "branch_id"], name: "idx_staff_branch_unique", unique: true
    t.index ["staff_member_id"], name: "index_staff_branches_on_staff_member_id"
    t.index ["workspace_id"], name: "index_staff_branches_on_workspace_id"
  end

  create_table "staff_levels", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "surcharge", default: 0, null: false
    t.integer "commission_percent"
    t.string "color"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "key"], name: "index_staff_levels_on_workspace_id_and_key", unique: true
    t.index ["workspace_id"], name: "index_staff_levels_on_workspace_id"
  end

  create_table "staff_members", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "branch_id"
    t.bigint "user_id"
    t.bigint "staff_level_id"
    t.string "code"
    t.string "name", null: false
    t.string "nickname"
    t.string "phone"
    t.string "email"
    t.string "gender"
    t.date "dob"
    t.string "role", default: "therapist", null: false
    t.string "employment_type", default: "fulltime", null: false
    t.date "hired_at"
    t.date "left_at"
    t.string "status", default: "active", null: false
    t.integer "base_salary", default: 0, null: false
    t.integer "commission_percent"
    t.boolean "online_bookable", default: true, null: false
    t.integer "max_daily_minutes"
    t.string "calendar_color"
    t.text "bio"
    t.decimal "rating_avg", precision: 3, scale: 2
    t.integer "rating_count", default: 0, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_staff_members_on_branch_id"
    t.index ["staff_level_id"], name: "index_staff_members_on_staff_level_id"
    t.index ["user_id"], name: "index_staff_members_on_user_id"
    t.index ["workspace_id", "code"], name: "index_staff_members_on_workspace_id_and_code"
    t.index ["workspace_id", "status"], name: "index_staff_members_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_staff_members_on_workspace_id"
  end

  create_table "staff_services", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "staff_member_id", null: false
    t.bigint "service_id", null: false
    t.integer "proficiency", default: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_staff_services_on_service_id"
    t.index ["staff_member_id", "service_id"], name: "idx_staff_service_unique", unique: true
    t.index ["staff_member_id"], name: "index_staff_services_on_staff_member_id"
    t.index ["workspace_id"], name: "index_staff_services_on_workspace_id"
  end

  create_table "staff_shifts", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "staff_member_id", null: false
    t.bigint "branch_id"
    t.date "work_date", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "kind", default: "shift", null: false
    t.string "status", default: "scheduled", null: false
    t.string "note"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_staff_shifts_on_branch_id"
    t.index ["staff_member_id", "work_date"], name: "index_staff_shifts_on_staff_member_id_and_work_date"
    t.index ["staff_member_id"], name: "index_staff_shifts_on_staff_member_id"
    t.index ["workspace_id", "work_date"], name: "index_staff_shifts_on_workspace_id_and_work_date"
    t.index ["workspace_id"], name: "index_staff_shifts_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "title"
    t.string "phone"
    t.string "locale", default: "vi", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "subdomain", null: false
    t.string "custom_domain"
    t.datetime "domain_verified_at"
    t.string "status", default: "trial", null: false
    t.string "plan", default: "starter", null: false
    t.string "locale_default", default: "vi", null: false
    t.string "business_type", default: "massage", null: false
    t.datetime "paid_until"
    t.boolean "auto_renew", default: false, null: false
    t.jsonb "theme", default: {}, null: false
    t.jsonb "branding", default: {}, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_domain"], name: "index_workspaces_on_custom_domain", unique: true, where: "(custom_domain IS NOT NULL)"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
    t.index ["status"], name: "index_workspaces_on_status"
    t.index ["subdomain"], name: "index_workspaces_on_subdomain", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "workspaces"
  add_foreign_key "booking_holds", "branches"
  add_foreign_key "booking_holds", "rooms"
  add_foreign_key "booking_holds", "staff_members"
  add_foreign_key "booking_holds", "workspaces"
  add_foreign_key "booking_items", "bookings"
  add_foreign_key "booking_items", "rooms"
  add_foreign_key "booking_items", "service_variants"
  add_foreign_key "booking_items", "services"
  add_foreign_key "booking_items", "staff_members"
  add_foreign_key "booking_items", "workspaces"
  add_foreign_key "bookings", "branches"
  add_foreign_key "bookings", "members"
  add_foreign_key "bookings", "workspaces"
  add_foreign_key "branch_closures", "branches"
  add_foreign_key "branch_closures", "workspaces"
  add_foreign_key "branch_hours", "branches"
  add_foreign_key "branch_hours", "workspaces"
  add_foreign_key "branches", "workspaces"
  add_foreign_key "broadcasts", "workspaces"
  add_foreign_key "conversations", "members"
  add_foreign_key "conversations", "workspaces"
  add_foreign_key "expenses", "branches"
  add_foreign_key "expenses", "workspaces"
  add_foreign_key "invoices", "workspaces"
  add_foreign_key "member_tiers", "workspaces"
  add_foreign_key "members", "branches", column: "home_branch_id"
  add_foreign_key "members", "member_tiers"
  add_foreign_key "members", "staff_members", column: "preferred_staff_id"
  add_foreign_key "members", "workspaces"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "workspaces"
  add_foreign_key "notifications", "broadcasts"
  add_foreign_key "notifications", "members"
  add_foreign_key "notifications", "workspaces"
  add_foreign_key "otp_challenges", "workspaces"
  add_foreign_key "push_subscriptions", "members"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "push_subscriptions", "workspaces"
  add_foreign_key "room_types", "workspaces"
  add_foreign_key "rooms", "branches"
  add_foreign_key "rooms", "room_types"
  add_foreign_key "rooms", "workspaces"
  add_foreign_key "service_categories", "workspaces"
  add_foreign_key "service_prices", "branches"
  add_foreign_key "service_prices", "service_variants"
  add_foreign_key "service_prices", "services"
  add_foreign_key "service_prices", "workspaces"
  add_foreign_key "service_variants", "services"
  add_foreign_key "service_variants", "workspaces"
  add_foreign_key "services", "service_categories"
  add_foreign_key "services", "workspaces"
  add_foreign_key "shift_templates", "branches"
  add_foreign_key "shift_templates", "staff_members"
  add_foreign_key "shift_templates", "workspaces"
  add_foreign_key "staff_branches", "branches"
  add_foreign_key "staff_branches", "staff_members"
  add_foreign_key "staff_branches", "workspaces"
  add_foreign_key "staff_levels", "workspaces"
  add_foreign_key "staff_members", "branches"
  add_foreign_key "staff_members", "staff_levels"
  add_foreign_key "staff_members", "users"
  add_foreign_key "staff_members", "workspaces"
  add_foreign_key "staff_services", "services"
  add_foreign_key "staff_services", "staff_members"
  add_foreign_key "staff_services", "workspaces"
  add_foreign_key "staff_shifts", "branches"
  add_foreign_key "staff_shifts", "staff_members"
  add_foreign_key "staff_shifts", "workspaces"
end
