require "rails_helper"

RSpec.describe OrderEvent, type: :model do
  let(:order) { create(:order, :paid) }

  it { is_expected.to belong_to(:order) }
  it { is_expected.to validate_presence_of(:event_type) }

  describe "#processed?" do
    it "is false when processed_at is nil" do
      event = order.order_events.create!(event_type: "payment_completed")
      expect(event).not_to be_processed
    end

    it "is true when processed_at is set" do
      event = order.order_events.create!(event_type: "payment_completed", processed_at: Time.current)
      expect(event).to be_processed
    end
  end

  describe "#process!" do
    it "sends the confirmation email and marks the event processed" do
      event = order.order_events.create!(event_type: "payment_completed")

      expect(event.process!).to be true

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to include(order.customer_email)
      expect(event.reload).to be_processed
    end

    it "is idempotent: a second call is a no-op and does not resend the email" do
      event = order.order_events.create!(event_type: "payment_completed")

      expect(event.process!).to be true
      expect(event.process!).to be false

      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "leaves processed_at nil and propagates the error when mail delivery raises" do
      event = order.order_events.create!(event_type: "payment_completed")
      allow(OrderMailer).to receive(:confirmation).and_raise(StandardError, "smtp down")

      expect { event.process! }.to raise_error(StandardError, "smtp down")

      expect(event.reload.processed_at).to be_nil
    end
  end
end
