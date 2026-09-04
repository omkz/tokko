class StripeWebhookEvent < ApplicationRecord
  validates :stripe_event_id, :event_type, :stripe_session_id, presence: true

  def processed?
    processed_at.present?
  end

  def process!
    with_lock do
      return false if processed?

      case event_type
      when "checkout.session.completed"
        complete_order if payment_status == "paid"
      when "checkout.session.async_payment_succeeded"
        complete_order
      when "checkout.session.async_payment_failed", "checkout.session.expired"
        expire_order
      end

      update!(processed_at: Time.current)
    end

    true
  end

  private

  def complete_order
    order = find_order
    return unless order

    order.complete_checkout_payment!
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
        Rails.logger.warn(
          "Ignoring Stripe session #{stripe_session_id} for order #{order.id}: stored session ID differs"
        )
        conflict = true
      end
    end

    order unless conflict
  end
end
