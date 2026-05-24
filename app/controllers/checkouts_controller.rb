class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_cart_not_empty, only: [ :new, :create ]
  before_action :set_saved_addresses, only: [ :new, :create ]

  def new
    @order = Order.new
    @order.customer_email = Current.user&.email_address
    @order.customer_name  = Current.user&.full_name
    @total_price = current_cart.total_price
  end

  def create
    cart = current_cart

    stock_errors = validate_stock(cart.cart_items.includes(product_variant: :product))
    if stock_errors.any?
      @order = Order.new(order_params)
      @total_price = cart.total_price
      flash.now[:alert] = stock_errors.to_sentence
      render :new, status: :unprocessable_entity
      return
    end

    @order, locked_errors = Order.create_from_cart!(cart, order_params)

    if locked_errors.any?
      @total_price = cart.total_price
      flash.now[:alert] = locked_errors.to_sentence
      render :new, status: :unprocessable_entity
    elsif @order.persisted?
      stripe_session = create_stripe_session(@order)
      @order.update_column(:stripe_checkout_session_id, stripe_session.id)
      cart.cart_items.destroy_all
      redirect_to stripe_session.url, allow_other_host: true
    else
      @total_price = cart.total_price
      render :new, status: :unprocessable_entity
    end
  end

  def payment_success
    stripe_session = Stripe::Checkout::Session.retrieve(params[:session_id])
    @order = Order.find_by!(stripe_checkout_session_id: stripe_session.id)
  end

  def success
    @order = Order.find(params[:order_id])
  end

  private

  def ensure_cart_not_empty
    if current_cart.nil? || current_cart.cart_items.empty?
      redirect_to root_path, alert: "Your cart is empty"
    end
  end

  def set_saved_addresses
    @saved_addresses = Current.user&.addresses&.order(is_default: :desc, created_at: :asc) || []
  end

  def order_params
    params.require(:order).permit(:customer_name, :customer_email, :customer_phone, :shipping_address)
  end

  def validate_stock(cart_items)
    cart_items.filter_map do |item|
      variant = item.product_variant
      if variant.stock == 0
        "#{variant.product.name} (#{variant.option_text}) is out of stock"
      elsif variant.stock < item.quantity
        "#{variant.product.name} (#{variant.option_text}) only has #{variant.stock} left in stock"
      end
    end
  end

  def create_stripe_session(order)
    line_items = order.order_items.includes(product_variant: :product).map do |item|
      {
        price_data: {
          currency: "usd",
          product_data: { name: "#{item.product_variant.product.name} — #{item.product_variant.title}" },
          unit_amount: (item.unit_price * 100).to_i
        },
        quantity: item.quantity
      }
    end

    Stripe::Checkout::Session.create(
      mode: "payment",
      customer_email: order.customer_email,
      line_items: line_items,
      metadata: { order_id: order.id },
      success_url: "#{request.base_url}/checkout/payment_success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{request.base_url}/checkout/new"
    )
  end
end
