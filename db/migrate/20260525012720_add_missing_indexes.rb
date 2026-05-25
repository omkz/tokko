class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    # Products: slug lookup on storefront, status filter on every listing
    add_index :products, :slug, unique: true
    add_index :products, :status

    # Orders: Stripe webhook lookup, dashboard badge count, email lookup
    add_index :orders, :stripe_checkout_session_id, unique: true
    add_index :orders, :status
    add_index :orders, :customer_email

    # Filter options: slug lookup for faceted filtering
    add_index :filter_options, :slug
  end
end
