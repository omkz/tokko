class AddOrderCreatedAtIndexAndUniqueConstraints < ActiveRecord::Migration[8.1]
  def change
    # Orders are always displayed sorted by created_at desc in the dashboard
    add_index :orders, :created_at

    # Prevent duplicate product memberships in a collection
    add_index :collection_memberships, [ :collection_id, :product_id ], unique: true

    # Prevent duplicate filter option tags on a product
    add_index :product_filter_options, [ :product_id, :filter_option_id ], unique: true
  end
end
