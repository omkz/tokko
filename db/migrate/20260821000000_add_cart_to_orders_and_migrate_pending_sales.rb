class AddCartToOrdersAndMigratePendingSales < ActiveRecord::Migration[8.1]
  def up
    add_reference :orders, :cart, foreign_key: true

    execute <<~SQL.squish
      UPDATE inventory_movements
      SET reason = 'reservation'
      FROM order_items, orders
      WHERE inventory_movements.order_item_id = order_items.id
        AND order_items.order_id = orders.id
        AND orders.status = 0
        AND inventory_movements.reason = 'sale'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE inventory_movements
      SET reason = 'sale'
      FROM order_items, orders
      WHERE inventory_movements.order_item_id = order_items.id
        AND order_items.order_id = orders.id
        AND orders.status = 0
        AND inventory_movements.reason = 'reservation'
    SQL

    remove_reference :orders, :cart, foreign_key: true
  end
end
