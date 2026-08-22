class ProcessStripeWebhookEventJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 10
  discard_on ActiveRecord::RecordNotFound

  def perform(id)
    StripeWebhookEvent.find(id).process!
  end
end
