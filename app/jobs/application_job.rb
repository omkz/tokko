class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  before_perform :set_error_context

  private

  def set_error_context
    Rails.error.set_context(
      job_class: self.class.name,
      job_id: job_id,
      queue_name: queue_name
    )
  end
end
