class ProcessOrderEventJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(id)
    OrderEvent.find(id).process!
  end
end
