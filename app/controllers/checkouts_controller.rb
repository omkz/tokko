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

    coupon_code = params.dig(:order, :coupon_code)
    @order, locked_errors = Order.create_from_cart!(cart, order_params, coupon_code: coupon_code)

    if locked_errors.any?
      @total_price = cart.total_price
      flash.now[:alert] = locked_errors.to_sentence
      render :new, status: :unprocessable_entity
    elsif @order.persisted?
      stripe_session_request_started = false
      begin
        stripe_coupon = create_stripe_coupon(@order)
        stripe_session_request_started = true
        stripe_session = create_stripe_session(@order, stripe_coupon)
      rescue Stripe::APIConnectionError, Stripe::APIError => error
        if stripe_session_request_started
          handle_indeterminate_checkout_session_error(error)
        else
          handle_definitive_checkout_session_error(error)
        end
        return
      rescue Stripe::StripeError, ActiveRecord::ActiveRecordError => error
        handle_definitive_checkout_session_error(error)
        return
      end

      begin
        @order.update!(stripe_checkout_session_id: stripe_session.id)
      rescue ActiveRecord::ActiveRecordError => error
        handle_indeterminate_checkout_session_error(error)
        return
      end

      redirect_to stripe_session.url, allow_other_host: true
    else
      @total_price = cart.total_price
      render :new, status: :unprocessable_entity
    end
  end

  def payment_success
    session_id = params.expect(:session_id)
    stripe_session = Stripe::Checkout::Session.retrieve(session_id)
    raise ActiveRecord::RecordNotFound unless stripe_session.id == session_id
    raise ActiveRecord::RecordNotFound unless stripe_session.payment_status == "paid"

    @order = Order.find_by!(stripe_checkout_session_id: stripe_session.id)
  rescue Stripe::InvalidRequestError
    raise ActiveRecord::RecordNotFound
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

  def create_stripe_session(order, stripe_coupon)
    line_items = order.order_items.map do |item|
      {
        price_data: {
          currency: "usd",
          product_data: { name: "#{item.product_name} — #{item.variant_options}" },
          unit_amount: (item.unit_price * 100).to_i
        },
        quantity: item.quantity
      }
    end

    session_params = {
      mode: "payment",
      customer_email: order.customer_email,
      line_items: line_items,
      client_reference_id: order.id.to_s,
      metadata: { order_id: order.id },
      expires_at: 30.minutes.from_now.to_i,
      success_url: "#{request.base_url}/checkout/payment_success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{request.base_url}/checkout/new"
    }

    session_params[:discounts] = [ { coupon: stripe_coupon.id } ] if stripe_coupon

    Stripe::Checkout::Session.create(
      session_params,
      { idempotency_key: "checkout-session-order-#{order.id}" }
    )
  end

  def create_stripe_coupon(order)
    return unless order.coupon.present? && order.discount_amount > 0

    Stripe::Coupon.create(
      {
        amount_off: (order.discount_amount * 100).to_i,
        currency: "usd",
        duration: "once"
      },
      { idempotency_key: "checkout-coupon-order-#{order.id}" }
    )
  end

  def handle_indeterminate_checkout_session_error(error)
    log_checkout_session_error(error)
    render_checkout_session_error("We're confirming your payment session. Please try again shortly.")
  end

  def handle_definitive_checkout_session_error(error)
    log_checkout_session_error(error)

    begin
      @order.reload
      @order.expire_checkout!
    rescue ActiveRecord::ActiveRecordError => cleanup_error
      Rails.logger.error(
        "Checkout reservation cleanup failed for order #{@order.id}: #{cleanup_error.class}: #{cleanup_error.message}"
      )
    end

    render_checkout_session_error("We couldn't start the payment session. Please try again.")
  end

  def log_checkout_session_error(error)
    Rails.logger.error(
      "Checkout session creation failed for order #{@order.id}: #{error.class}: #{error.message}"
    )
  end

  def render_checkout_session_error(message)
    @order = Order.new(order_params)
    @total_price = current_cart.total_price
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
