class CreateInventoryMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_movements do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :order_item, null: true, foreign_key: true
      t.integer :quantity, null: false
      t.string :reason, null: false
      t.text :note

      t.timestamps
    end
  end
end
