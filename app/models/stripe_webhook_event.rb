class StripeWebhookEvent < ApplicationRecord
  validates :stripe_event_id, :event_type, :stripe_session_id, presence: true

  def processed?
    processed_at.present?
  end

  def process!
    paid_order = nil

    with_lock do
      return false if processed?

      case event_type
      when "checkout.session.completed"
        paid_order = complete_order if payment_status == "paid"
      when "checkout.session.async_payment_succeeded"
        paid_order = complete_order
      when "checkout.session.async_payment_failed", "checkout.session.expired"
        expire_order
      end

      update!(processed_at: Time.current)
    end

    # Enqueued only after the transaction above has committed, so the job
    # never races the OrderEvent it depends on. If this enqueue is lost
    # (process crash, queue outage) the durable outbox recovery job is the
    # safety net.
    paid_order&.enqueue_pending_payment_event

    true
  end

  private

  # Returns the order if this call won the pending -> paid transition, so
  # the caller can enqueue its outbox event once the transaction commits.
  def complete_order
    order = find_order
    return unless order

    order if order.complete_checkout_payment!
  end

  def expire_order
    find_order&.expire_checkout!
  end

  def find_order
    order = Order.find_by(stripe_checkout_session_id: stripe_session_id)
    return order if order
    return if metadata_order_id.blank?

    order = Order.find_by(id: metadata_order_id)
    return unless order

    conflict = false
    order.with_lock do
      if order.stripe_checkout_session_id.blank?
        order.update!(stripe_checkout_session_id: stripe_session_id)
      elsif order.stripe_checkout_session_id != stripe_session_id
        Rails.logger.warn({
          event: "checkout_warning",
          reason: "stripe_session_conflict",
          order_id: order.id,
          incoming_stripe_session_id: stripe_session_id,
          stored_stripe_session_id: order.stripe_checkout_session_id
        }.to_json)
        conflict = true
      end
    end

    order unless conflict
  end
end
