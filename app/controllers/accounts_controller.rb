class AccountsController < ApplicationController
  def show
    @recent_orders = Order.includes(:order_items)
                          .where(customer_email: Current.user.email_address)
                          .order(created_at: :desc)
                          .limit(3)

    @wishlist_count = Current.user.wishlist_items.count
    @orders_count   = Order.where(customer_email: Current.user.email_address).count
  end
end
