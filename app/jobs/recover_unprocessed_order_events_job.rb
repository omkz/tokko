class RecoverUnprocessedOrderEventsJob < ApplicationJob
  def perform
    OrderEvent.where(processed_at: nil).find_each do |event|
      ProcessOrderEventJob.perform_later(event.id)
    end
  end
end
