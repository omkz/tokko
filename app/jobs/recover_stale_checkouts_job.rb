class RecoverStaleCheckoutsJob < ApplicationJob
  retry_on Stripe::APIConnectionError, Stripe::APIError,
           wait: :polynomially_longer, attempts: 5

  def perform
    Order.stale_pending_checkout.find_each do |order|
      reconcile(order)
    end
  end

  private

  def reconcile(order)
    if order.stripe_checkout_session_id.blank?
      Rails.logger.warn(
        "Order #{order.id}: cannot reconcile stale checkout, local Stripe session ID is missing"
      )
      return
    end

    session = Stripe::Checkout::Session.retrieve(order.stripe_checkout_session_id)
    apply_session(order, session)
  rescue Stripe::InvalidRequestError
    Rails.logger.error(
      "Order #{order.id}: Stripe checkout session #{order.stripe_checkout_session_id} could not be retrieved"
    )
  end

  def apply_session(order, session)
    if session.payment_status == "paid"
      order.enqueue_pending_payment_event if order.complete_checkout_payment!
    elsif session.status == "expired"
      order.expire_checkout!
    end
  end
end
