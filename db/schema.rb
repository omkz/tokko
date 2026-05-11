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

ActiveRecord::Schema[8.1].define(version: 2026_05_11_040202) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.integer "stock"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "slug"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "variant_option_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_option_value_id", null: false
    t.bigint "product_variant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_option_value_id"], name: "index_variant_option_values_on_product_option_value_id"
    t.index ["product_variant_id"], name: "index_variant_option_values_on_product_variant_id"
  end

  add_foreign_key "product_option_values", "product_options"
  add_foreign_key "product_options", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "variant_option_values", "product_option_values"
  add_foreign_key "variant_option_values", "product_variants"
end
