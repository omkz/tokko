class OrdersController < ApplicationController
  def index
    @pagy, @orders = pagy(
      Order.includes(:order_items).where(customer_email: Current.user.email_address).order(created_at: :desc)
    )
  end

  def show
    @order = Order.includes(order_items: { product_variant: { product: { images_attachments: :blob } } })
                  .where(customer_email: Current.user.email_address)
                  .find(params[:id])
    @order_items = @order.order_items
  end
end
