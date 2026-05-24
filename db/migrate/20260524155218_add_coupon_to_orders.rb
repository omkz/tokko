class AddCouponToOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :coupon, null: true, foreign_key: true
    add_column :orders, :discount_amount, :decimal, default: 0, null: false
  end
end
