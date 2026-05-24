class CreateCartsAndCartItems < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.references :user, null: true, foreign_key: true, index: { unique: true }
      t.string :token, null: false, index: { unique: true }
      t.datetime :expires_at

      t.timestamps
    end

    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :cart_items, [ :cart_id, :product_variant_id ], unique: true
  end
end
