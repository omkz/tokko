require "rails_helper"

RSpec.describe ProcessStripeWebhookEventJob, type: :job do
  it "allows duplicate jobs while processing the event only once" do
    variant = create(:product_variant, stock: 10)
    order = create(:order, stripe_checkout_session_id: "cs_test_abc123")
    order_item = create(:order_item, order: order, product_variant: variant, quantity: 2)
    create(
      :inventory_movement,
      product_variant: variant,
      order_item: order_item,
      quantity: -2,
      reason: :reservation
    )
    event = StripeWebhookEvent.create!(
      stripe_event_id: "evt_test_123",
      event_type: "checkout.session.completed",
      stripe_session_id: order.stripe_checkout_session_id,
      payment_status: "paid"
    )

    expect {
      described_class.perform_now(event.id)
      described_class.perform_now(event.id)
    }.to change { order.order_events.count }.by(1)

    expect(event.reload).to be_processed
    expect(order.reload).to be_paid
    expect(order.inventory_movements.reload.sole).to be_sale
    expect(variant.reload.stock).to eq(8)
  end

  it "discards the job when its event has been deleted" do
    event = StripeWebhookEvent.create!(
      stripe_event_id: "evt_test_deleted",
      event_type: "checkout.session.expired",
      stripe_session_id: "cs_test_deleted"
    )
    event.destroy!

    expect { described_class.perform_now(event.id) }.not_to raise_error
  end

  it "retries processing failures" do
    event = StripeWebhookEvent.create!(
      stripe_event_id: "evt_test_retry",
      event_type: "checkout.session.expired",
      stripe_session_id: "cs_test_retry"
    )
    allow(StripeWebhookEvent).to receive(:find).with(event.id).and_return(event)
    allow(event).to receive(:process!).and_raise("temporary failure")

    expect { described_class.perform_now(event.id) }
      .to have_enqueued_job(described_class).with(event.id)
  end
end
