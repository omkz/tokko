class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :customer_name
      t.string :customer_email
      t.string :customer_phone
      t.text :shipping_address
      t.decimal :total_price
      t.integer :status

      t.timestamps
    end
  end
end
