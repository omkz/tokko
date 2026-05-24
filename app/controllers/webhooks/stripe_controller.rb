class Webhooks::StripeController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token

  def create
    payload   = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)

    case event["type"]
    when "checkout.session.completed"
      handle_checkout_completed(event["data"]["object"])
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def handle_checkout_completed(session)
    order = Order.find_by(stripe_checkout_session_id: session["id"])
    return unless order
    return if order.paid?

    order.update!(status: :paid)
    OrderMailer.confirmation(order).deliver_later

    user = User.find_by(email_address: order.customer_email)
    Cart.find_by(user: user)&.cart_items&.destroy_all
  end
end
