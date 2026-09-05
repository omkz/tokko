class CreateOrderEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :order_events do |t|
      t.bigint :order_id, null: false
      t.string :event_type, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_foreign_key :order_events, :orders

    add_index :order_events, [ :processed_at, :order_id ],
              where: "processed_at IS NULL",
              name: "index_order_events_on_unprocessed"

    add_index :order_events,
              :order_id,
              unique: true,
              where: "event_type = 'payment_completed'",
              name: "index_order_events_unique_payment_completed"
  end
end
