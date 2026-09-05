class OrderEvent < ApplicationRecord
  belongs_to :order

  validates :event_type, presence: true

  def processed?
    processed_at.present?
  end

  # Idempotent: safe to call concurrently or more than once for the same
  # event, so duplicate enqueues from recovery are harmless.
  def process!
    with_lock do
      return false if processed?

      case event_type
      when "payment_completed"
        OrderMailer.confirmation(order).deliver_now
      end

      update!(processed_at: Time.current)
    end

    true
  end
end
