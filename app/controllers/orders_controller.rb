class OrdersController < ApplicationController
  before_action :require_authentication

  def index
    @orders = Current.user.orders.order(created_at: :desc)
    @pagy, @orders = pagy(@orders)
  end

  def show
    @order = Current.user.orders.find(params[:id])
    @order_items = @order.order_items.includes(product_variant: :product)
  end
end
