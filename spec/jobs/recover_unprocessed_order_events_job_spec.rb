require "rails_helper"

RSpec.describe RecoverUnprocessedOrderEventsJob, type: :job do
  let(:order) { create(:order, :paid) }

  it "enqueues unprocessed events for processing" do
    event = order.order_events.create!(event_type: "payment_completed")

    expect { described_class.perform_now }
      .to have_enqueued_job(ProcessOrderEventJob).with(event.id)
  end

  it "does not enqueue already-processed events" do
    order.order_events.create!(event_type: "payment_completed", processed_at: Time.current)

    expect { described_class.perform_now }
      .not_to have_enqueued_job(ProcessOrderEventJob)
  end

  it "may enqueue duplicates across runs without duplicate successful processing" do
    event = order.order_events.create!(event_type: "payment_completed")

    expect {
      described_class.perform_now
      described_class.perform_now
    }.to have_enqueued_job(ProcessOrderEventJob).with(event.id).twice

    ProcessOrderEventJob.perform_now(event.id)
    ProcessOrderEventJob.perform_now(event.id)

    expect(event.reload).to be_processed
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end
end
