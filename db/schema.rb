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

ActiveRecord::Schema[8.1].define(version: 2026_05_24_030444) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.bigint "parent_id"
    t.integer "position"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "collection_memberships", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_collection_memberships_on_collection_id"
    t.index ["product_id"], name: "index_collection_memberships_on_product_id"
  end

  create_table "collections", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_collections_on_slug", unique: true
  end

  create_table "filter_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "position"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_filter_groups_on_slug", unique: true
  end

  create_table "filter_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "filter_group_id", null: false
    t.integer "position"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["filter_group_id"], name: "index_filter_options_on_filter_group_id"
  end

  create_table "inventory_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.bigint "order_item_id"
    t.bigint "product_variant_id", null: false
    t.integer "quantity", null: false
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["order_item_id"], name: "index_inventory_movements_on_order_item_id"
    t.index ["product_variant_id"], name: "index_inventory_movements_on_product_variant_id"
    t.index ["user_id"], name: "index_inventory_movements_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity"
    t.decimal "unit_price"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "customer_email"
    t.string "customer_name"
    t.string "customer_phone"
    t.text "shipping_address"
    t.integer "status"
    t.string "stripe_checkout_session_id"
    t.decimal "total_price"
    t.datetime "updated_at", null: false
  end

  create_table "product_filter_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "filter_option_id", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["filter_option_id"], name: "index_product_filter_options_on_filter_option_id"
    t.index ["product_id"], name: "index_product_filter_options_on_product_id"
  end

  create_table "product_option_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position"
    t.bigint "product_option_id", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["product_option_id"], name: "index_product_option_values_on_product_option_id"
  end

  create_table "product_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "position"
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_options_on_product_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.decimal "price"
    t.bigint "product_id", null: false
    t.string "sku"
    t.integer "stock", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.check_constraint "stock >= 0", name: "stock_non_negative"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "variant_option_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_option_value_id", null: false
    t.bigint "product_variant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_option_value_id"], name: "index_variant_option_values_on_product_option_value_id"
    t.index ["product_variant_id"], name: "index_variant_option_values_on_product_variant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "collection_memberships", "collections"
  add_foreign_key "collection_memberships", "products"
  add_foreign_key "filter_options", "filter_groups"
  add_foreign_key "inventory_movements", "order_items"
  add_foreign_key "inventory_movements", "product_variants"
  add_foreign_key "inventory_movements", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "product_filter_options", "filter_options"
  add_foreign_key "product_filter_options", "products"
  add_foreign_key "product_option_values", "product_options"
  add_foreign_key "product_options", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "sessions", "users"
  add_foreign_key "variant_option_values", "product_option_values"
  add_foreign_key "variant_option_values", "product_variants"
end
