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
      session = event["data"]["object"]
      complete_order(session) if session["payment_status"] == "paid"
    when "checkout.session.async_payment_succeeded"
      complete_order(event["data"]["object"])
    when "checkout.session.async_payment_failed", "checkout.session.expired"
      expire_order(event["data"]["object"])
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def complete_order(session)
    order = Order.find_by(stripe_checkout_session_id: session["id"])
    return unless order
    return unless order.complete_payment!

    OrderMailer.confirmation(order).deliver_later
    order.cart&.cart_items&.destroy_all
  end

  def expire_order(session)
    Order.find_by(stripe_checkout_session_id: session["id"])&.expire_checkout!
  end
end
