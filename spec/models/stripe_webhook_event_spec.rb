require "rails_helper"

RSpec.describe StripeWebhookEvent, type: :model do
  let(:cart) { create(:cart) }
  let(:variant) { create(:product_variant, stock: 10) }
  let(:order) do
    create(:order, cart: cart, stripe_checkout_session_id: "cs_test_abc123").tap do |created_order|
      item = create(:order_item, order: created_order, product_variant: variant, quantity: 2)
      create(:inventory_movement, product_variant: variant, order_item: item, quantity: -2, reason: :reservation)
    end
  end

  def create_event(type:, session_id: nil, payment_status: nil, metadata_order_id: nil)
    @event_number = @event_number.to_i + 1
    described_class.create!(
      stripe_event_id: "evt_test_#{@event_number}",
      event_type: type,
      stripe_session_id: session_id || order.stripe_checkout_session_id,
      payment_status: payment_status,
      metadata_order_id: metadata_order_id
    )
  end

  it { is_expected.to validate_presence_of(:stripe_event_id) }
  it { is_expected.to validate_presence_of(:event_type) }
  it { is_expected.to validate_presence_of(:stripe_session_id) }

  describe "#process!" do
    it "completes a paid checkout, finalizes inventory, records one payment event, and clears its cart" do
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      event = create_event(type: "checkout.session.completed", payment_status: "paid")

      expect { event.process! }.to have_enqueued_job(ProcessOrderEventJob)

      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.stock).to eq(8)
      expect(cart.cart_items.reload).to be_empty
      expect(event.reload).to be_processed
      expect(order.order_events.sole.event_type).to eq("payment_completed")
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "enqueues the persisted payment event only after its transaction has committed" do
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      event = create_event(type: "checkout.session.completed", payment_status: "paid")
      baseline_depth = ActiveRecord::Base.connection.open_transactions

      depth_at_enqueue = nil
      order_event_id_at_enqueue = nil
      allow(ProcessOrderEventJob).to receive(:perform_later) do |id|
        depth_at_enqueue = ActiveRecord::Base.connection.open_transactions
        order_event_id_at_enqueue = id
      end

      event.process!

      persisted_event = order.order_events.sole
      expect(depth_at_enqueue).to eq(baseline_depth)
      expect(order_event_id_at_enqueue).to eq(persisted_event.id)
      expect(order.reload).to be_paid
      expect(event.reload).to be_processed
    end

    it "marks an unpaid completion processed without changing payment state" do
      item = create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      event = create_event(type: "checkout.session.completed", payment_status: "unpaid")

      expect { event.process! }.not_to have_enqueued_job(ProcessOrderEventJob)

      expect(order.reload).to be_pending
      expect(order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)
      expect(cart.cart_items).to include(item)
      expect(event.reload).to be_processed
      expect(order.order_events).to be_empty
    end

    it "completes an asynchronous payment success" do
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      event = create_event(type: "checkout.session.async_payment_succeeded")

      expect { event.process! }.to have_enqueued_job(ProcessOrderEventJob)

      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.reload.stock).to eq(8)
      expect(cart.cart_items.reload).to be_empty
    end

    %w[
      checkout.session.async_payment_failed
      checkout.session.expired
    ].each do |event_type|
      it "expires checkout for #{event_type}" do
        item = create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
        event = create_event(type: event_type)

        event.process!

        expect(order.reload).to be_cancelled
        expect(variant.reload.stock).to eq(10)
        expect(order.inventory_movements.pluck(:reason)).to contain_exactly("reservation", "release")
        expect(cart.cart_items).to include(item)
      end
    end

    it "reconciles and persists a missing local Stripe session ID from metadata" do
      order.update!(stripe_checkout_session_id: nil)
      event = create_event(
        type: "checkout.session.completed",
        session_id: "cs_test_reconciled",
        payment_status: "paid",
        metadata_order_id: order.id
      )

      event.process!

      expect(order.reload).to be_paid
      expect(order.stripe_checkout_session_id).to eq("cs_test_reconciled")
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.reload.stock).to eq(8)
    end

    it "logs and refuses a conflicting Stripe session ID" do
      event = create_event(
        type: "checkout.session.completed",
        session_id: "cs_test_conflicting",
        payment_status: "paid",
        metadata_order_id: order.id
      )
      allow(Rails.logger).to receive(:warn)

      event.process!

      expect(Rails.logger).to have_received(:warn) do |payload|
        parsed = JSON.parse(payload)
        expect(parsed).to eq(
          "event" => "checkout_warning",
          "reason" => "stripe_session_conflict",
          "order_id" => order.id,
          "incoming_stripe_session_id" => "cs_test_conflicting",
          "stored_stripe_session_id" => "cs_test_abc123"
        )
      end
      expect(order.reload).to be_pending
      expect(order.stripe_checkout_session_id).to eq("cs_test_abc123")
      expect(order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)
    end

    it "marks an event for an unknown order processed without changing orders" do
      event = create_event(
        type: "checkout.session.completed",
        session_id: "cs_test_unknown",
        payment_status: "paid",
        metadata_order_id: Order.maximum(:id).to_i + 1
      )

      expect { event.process! }.not_to change { Order.pluck(:status) }

      expect(event.reload).to be_processed
    end

    it "processes the same event only once" do
      event = create_event(type: "checkout.session.completed", payment_status: "paid")
      results = []

      expect {
        results << event.process!
        results << event.process!
      }.to change(OrderEvent, :count).by(1)

      expect(results).to eq([ true, false ])
      expect(event.reload.processed_at).to be_present
      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.reload.stock).to eq(8)
    end

    it "leaves processed_at nil when processing raises" do
      event = create_event(type: "checkout.session.completed", payment_status: "paid")
      allow(event).to receive(:complete_order).and_raise(ActiveRecord::Deadlocked)

      expect { event.process! }.to raise_error(ActiveRecord::Deadlocked)

      expect(event.reload.processed_at).to be_nil
    end
  end
end
