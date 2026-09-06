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
      Rails.logger.warn({
        event: "checkout_warning",
        reason: "missing_stripe_session_id",
        order_id: order.id
      }.to_json)
      return
    end

    session = Stripe::Checkout::Session.retrieve(order.stripe_checkout_session_id)
    apply_session(order, session)
  rescue Stripe::InvalidRequestError => error
    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: {
        operation: "reconcile_stale_checkout",
        order_id: order.id,
        stripe_checkout_session_id: order.stripe_checkout_session_id
      }
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
