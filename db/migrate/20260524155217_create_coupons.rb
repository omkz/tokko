class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons do |t|
      t.string :code
      t.string :discount_type
      t.decimal :value
      t.decimal :minimum_order
      t.integer :usage_limit
      t.datetime :expires_at
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :coupons, :code, unique: true
  end
end
