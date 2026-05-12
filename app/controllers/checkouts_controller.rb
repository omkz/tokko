class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_cart_not_empty

  def new
    @order = Order.new
    if authenticated?
      @order.customer_name = Current.user.email_address.split('@').first.capitalize
      @order.customer_email = Current.user.email_address
    end
    @total_price = cart_total_price
  end

  def create
    @order = Order.new(order_params)
    @order.total_price = cart_total_price
    @order.status = :pending
    @order.user = Current.user if authenticated?

    if @order.save
      # Move items from cart to OrderItems
      session[:cart].each do |variant_id, quantity|
        variant = ProductVariant.find(variant_id)
        @order.order_items.create!(
          product_variant: variant,
          quantity: quantity,
          unit_price: variant.price
        )
      end

      # Clear cart
      session[:cart] = {}

      redirect_to success_checkout_path(order_id: @order.id), notice: "Order placed successfully!"
    else
      @total_price = cart_total_price
      render :new, status: :unprocessable_entity
    end
  end

  def success
    @order = Order.find(params[:order_id])
  end

  private

  def ensure_cart_not_empty
    if session[:cart].blank?
      redirect_to root_path, alert: "Your cart is empty"
    end
  end

  def order_params
    params.require(:order).permit(:customer_name, :customer_email, :customer_phone, :shipping_address)
  end

  def cart_total_price
    helpers.cart_total_price
  end
end
