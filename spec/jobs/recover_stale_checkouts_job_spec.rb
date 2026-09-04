require "rails_helper"

RSpec.describe RecoverStaleCheckoutsJob, type: :job do
  let(:variant) { create(:product_variant, stock: 10) }

  def build_stale_order(session_id: "cs_test_stale", created_at: 50.minutes.ago, cart: nil)
    order = create(:order, cart: cart, stripe_checkout_session_id: session_id, created_at: created_at)
    item = create(:order_item, order: order, product_variant: variant, quantity: 2)
    create(:inventory_movement, product_variant: variant, order_item: item, quantity: -2, reason: :reservation)
    order
  end

  def stub_session(session_id, status:, payment_status:)
    session = double("Stripe::Checkout::Session", status: status, payment_status: payment_status)
    allow(Stripe::Checkout::Session).to receive(:retrieve).with(session_id).and_return(session)
    session
  end

  describe "stale pending order with a remote expired session" do
    it "cancels the order and releases its reservation" do
      order = build_stale_order(session_id: "cs_test_expired")
      stub_session("cs_test_expired", status: "expired", payment_status: "unpaid")

      described_class.perform_now

      expect(order.reload).to be_cancelled
      expect(order.inventory_movements.pluck(:reason)).to contain_exactly("reservation", "release")
      expect(variant.reload.stock).to eq(10)
    end
  end

  describe "stale pending order with a remote paid session" do
    it "completes payment, sells the reservation, emails once, and clears the cart" do
      cart = create(:cart)
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      order = build_stale_order(session_id: "cs_test_paid", cart: cart)
      stub_session("cs_test_paid", status: "complete", payment_status: "paid")

      expect { described_class.perform_now }.to have_enqueued_mail(OrderMailer, :confirmation).once

      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.reload.stock).to eq(8)
      expect(cart.cart_items.reload).to be_empty
    end

    it "has payment side effects only once when run twice against the same paid session" do
      cart = create(:cart)
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      order = build_stale_order(session_id: "cs_test_paid_twice", cart: cart)
      stub_session("cs_test_paid_twice", status: "complete", payment_status: "paid")

      expect {
        described_class.perform_now
        described_class.perform_now
      }.to have_enqueued_mail(OrderMailer, :confirmation).once

      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.reload.stock).to eq(8)
    end
  end

  describe "stale pending order with a remote complete but unpaid session" do
    it "remains pending with stock still reserved and no side effects" do
      cart = create(:cart)
      item = create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      order = build_stale_order(session_id: "cs_test_unpaid", cart: cart)
      stub_session("cs_test_unpaid", status: "complete", payment_status: "unpaid")

      expect { described_class.perform_now }.not_to have_enqueued_mail(OrderMailer, :confirmation)

      expect(order.reload).to be_pending
      expect(order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)
      expect(cart.cart_items).to include(item)
    end
  end

  describe "stale pending order with a remote open session" do
    it "remains pending with stock still reserved" do
      order = build_stale_order(session_id: "cs_test_open")
      stub_session("cs_test_open", status: "open", payment_status: "unpaid")

      described_class.perform_now

      expect(order.reload).to be_pending
      expect(order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)
    end
  end

  describe "a recent pending order" do
    it "is not reconciled with Stripe" do
      order = build_stale_order(session_id: "cs_test_recent", created_at: 5.minutes.ago)
      expect(Stripe::Checkout::Session).not_to receive(:retrieve)

      described_class.perform_now

      expect(order.reload).to be_pending
    end
  end

  describe "a non-pending order" do
    it "is not reconciled" do
      order = create(:order, :paid, stripe_checkout_session_id: "cs_test_already_paid", created_at: 50.minutes.ago)
      expect(Stripe::Checkout::Session).not_to receive(:retrieve)

      described_class.perform_now

      expect(order.reload).to be_paid
    end
  end

  describe "stale pending order with a missing local Stripe session ID" do
    it "remains pending, logs a warning, and does not contact Stripe" do
      order = create(:order, stripe_checkout_session_id: nil, created_at: 50.minutes.ago)
      item = create(:order_item, order: order, product_variant: variant, quantity: 2)
      create(:inventory_movement, product_variant: variant, order_item: item, quantity: -2, reason: :reservation)
      allow(Rails.logger).to receive(:warn)
      expect(Stripe::Checkout::Session).not_to receive(:retrieve)

      described_class.perform_now

      expect(Rails.logger).to have_received(:warn).with(
        "Order #{order.id}: cannot reconcile stale checkout, local Stripe session ID is missing"
      )
      expect(order.reload).to be_pending
      expect(order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)
    end
  end

  describe "an unknown Stripe checkout session" do
    it "logs an error, leaves the order pending, and continues reconciling later orders" do
      unknown_order = build_stale_order(session_id: "cs_test_unknown")
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_test_unknown")
        .and_raise(Stripe::InvalidRequestError.new("No such checkout session", "id"))

      other_cart = create(:cart)
      other_variant = create(:product_variant, stock: 10)
      create(:cart_item, cart: other_cart, product_variant: other_variant, quantity: 1)
      paid_order = create(:order, cart: other_cart, stripe_checkout_session_id: "cs_test_paid_after", created_at: 50.minutes.ago)
      paid_item = create(:order_item, order: paid_order, product_variant: other_variant, quantity: 1)
      create(:inventory_movement, product_variant: other_variant, order_item: paid_item, quantity: -1, reason: :reservation)
      stub_session("cs_test_paid_after", status: "complete", payment_status: "paid")

      allow(Rails.logger).to receive(:error)

      described_class.perform_now

      expect(Rails.logger).to have_received(:error).with(
        "Order #{unknown_order.id}: Stripe checkout session cs_test_unknown could not be retrieved"
      )
      expect(unknown_order.reload).to be_pending
      expect(unknown_order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)

      expect(paid_order.reload).to be_paid
      expect(paid_order.inventory_movements.reload.sole).to be_sale
    end
  end

  describe "a transient Stripe API failure" do
    it "is retried according to the job's retry policy and leaves local state unchanged" do
      order = build_stale_order(session_id: "cs_test_transient")
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .with("cs_test_transient")
        .and_raise(Stripe::APIConnectionError.new("connection reset"))

      expect { described_class.perform_now }.to have_enqueued_job(described_class)

      expect(order.reload).to be_pending
      expect(order.inventory_movements.reload.sole).to be_reservation
      expect(variant.reload.stock).to eq(8)
    end
  end

  describe "webhook/recovery idempotency" do
    it "does not duplicate email, inventory sale, or cart cleanup when recovery runs after the webhook already completed payment" do
      cart = create(:cart)
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      order = build_stale_order(session_id: "cs_test_webhook_first", cart: cart)
      event = StripeWebhookEvent.create!(
        stripe_event_id: "evt_test_recovery_race",
        event_type: "checkout.session.completed",
        stripe_session_id: order.stripe_checkout_session_id,
        payment_status: "paid"
      )

      expect { event.process! }.to have_enqueued_mail(OrderMailer, :confirmation).once
      expect(Stripe::Checkout::Session).not_to receive(:retrieve)

      expect { described_class.perform_now }.not_to have_enqueued_mail(OrderMailer, :confirmation)

      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
      expect(variant.reload.stock).to eq(8)
      expect(cart.cart_items.reload).to be_empty
    end
  end
end
