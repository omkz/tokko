class ProcessOrderEventJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 10
  discard_on ActiveRecord::RecordNotFound

  def perform(id)
    OrderEvent.find(id).process!
  end
end
