require "rails_helper"

RSpec.describe ApplicationJob do
  it "sets job_class, job_id, and queue_name as error context before performing" do
    job = RecoverUnprocessedOrderEventsJob.new
    captured_context = nil
    allow(Rails.error).to receive(:set_context) { |context| captured_context = context }

    job.perform_now

    expect(captured_context).to eq(
      job_class: "RecoverUnprocessedOrderEventsJob",
      job_id: job.job_id,
      queue_name: job.queue_name
    )
  end
end
