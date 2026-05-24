class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_cart_not_empty, only: [ :new, :create ]

  def new
    @order = Order.new
    @order.customer_email = Current.user&.email_address
    @total_price = cart_total_price
  end

  def create
    stock_errors = validate_cart_stock
    if stock_errors.any?
      @order = Order.new(order_params)
      @total_price = cart_total_price
      flash.now[:alert] = stock_errors.to_sentence
      render :new, status: :unprocessable_entity
      return
    end

    @order = Order.new(order_params)
    @order.total_price = cart_total_price
    @order.status = :pending

    locked_errors = []
    sorted_cart = session[:cart].sort_by { |variant_id, _| variant_id.to_i }

    ActiveRecord::Base.transaction do
      sorted_cart.each do |variant_id, quantity|
        variant = ProductVariant.lock.includes(:product).find(variant_id)
        if variant.stock < quantity.to_i
          msg = variant.stock == 0 ?
            "#{variant.product.name} (#{variant.option_text}) is out of stock" :
            "#{variant.product.name} (#{variant.option_text}) only has #{variant.stock} left in stock"
          locked_errors << msg
        end
      end

      raise ActiveRecord::Rollback if locked_errors.any?
      raise ActiveRecord::Rollback unless @order.save

      sorted_cart.each do |variant_id, quantity|
        variant = ProductVariant.lock.find(variant_id)
        order_item = @order.order_items.create!(
          product_variant: variant,
          quantity: quantity,
          unit_price: variant.price
        )
        InventoryMovement.create!(
          product_variant: variant,
          quantity: -quantity.to_i,
          reason: :sale,
          order_item: order_item
        )
      end
    end

    if locked_errors.any?
      @total_price = cart_total_price
      flash.now[:alert] = locked_errors.to_sentence
      render :new, status: :unprocessable_entity
    elsif @order.persisted?
      session[:cart] = {}
      stripe_session = create_stripe_session(@order)
      @order.update_column(:stripe_checkout_session_id, stripe_session.id)
      redirect_to stripe_session.url, allow_other_host: true
    else
      @total_price = cart_total_price
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

  def validate_cart_stock
    errors = []
    session[:cart].each do |variant_id, quantity|
      variant = ProductVariant.includes(:product).find_by(id: variant_id)
      next unless variant
      if variant.stock == 0
        errors << "#{variant.product.name} (#{variant.option_text}) is out of stock"
      elsif variant.stock < quantity.to_i
        errors << "#{variant.product.name} (#{variant.option_text}) only has #{variant.stock} left in stock"
      end
    end
    errors
  end
end
