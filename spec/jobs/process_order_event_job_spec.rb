require "rails_helper"

RSpec.describe ProcessOrderEventJob, type: :job do
  let(:order) { create(:order, :paid) }

  it "processes the event and sends the confirmation email" do
    event = order.order_events.create!(event_type: "payment_completed")

    described_class.perform_now(event.id)

    expect(event.reload).to be_processed
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "allows duplicate job execution to be harmless" do
    event = order.order_events.create!(event_type: "payment_completed")

    described_class.perform_now(event.id)
    described_class.perform_now(event.id)

    expect(event.reload).to be_processed
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "discards the job when its event has been deleted, without re-enqueueing a retry" do
    event = order.order_events.create!(event_type: "payment_completed")
    id = event.id
    event.destroy!

    expect {
      expect { described_class.perform_now(id) }.not_to raise_error
    }.not_to have_enqueued_job(described_class)
  end

  it "retries when processing fails" do
    event = order.order_events.create!(event_type: "payment_completed")
    allow(OrderEvent).to receive(:find).with(event.id).and_return(event)
    allow(event).to receive(:process!).and_raise("temporary failure")

    expect { described_class.perform_now(event.id) }
      .to have_enqueued_job(described_class).with(event.id)

    expect(event.reload.processed_at).to be_nil
  end
end
