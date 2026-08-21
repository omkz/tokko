require "rails_helper"

RSpec.describe "Webhooks::Stripe", type: :request do
  let(:cart) { create(:cart) }
  let(:variant) { create(:product_variant, stock: 10) }
  let(:order) do
    create(:order, cart: cart, stripe_checkout_session_id: "cs_test_abc123").tap do |created_order|
      item = create(:order_item, order: created_order, product_variant: variant, quantity: 2)
      create(:inventory_movement, product_variant: variant, order_item: item, quantity: -2, reason: :reservation)
    end
  end

  def stripe_event(type:, session_id:, payment_status: nil, order_id: nil)
    session = { "id" => session_id }
    session["payment_status"] = payment_status if payment_status
    session["metadata"] = { "order_id" => order_id.to_s } if order_id

    {
      "type" => type,
      "data" => {
        "object" => session
      }
    }.to_json
  end

  def post_webhook(payload, signature: "valid_sig")
    post webhooks_stripe_path,
      params: payload,
      headers: { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
  end

  before do
    allow(Stripe::Webhook).to receive(:construct_event) do |payload, sig, _secret|
      raise Stripe::SignatureVerificationError.new("bad sig", sig) if sig == "invalid_sig"
      JSON.parse(payload)
    end
  end

  describe "POST /webhooks/stripe" do
    context "with a paid checkout.session.completed event" do
      let(:payload) do
        stripe_event(
          type: "checkout.session.completed",
          session_id: order.stripe_checkout_session_id,
          payment_status: "paid"
        )
      end

      it "returns 200 OK" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
      end

      it "marks the order as paid" do
        post_webhook(payload)
        expect(order.reload.status).to eq("paid")
      end

      it "finalizes the reservation as a sale without changing stock again" do
        order

        expect { post_webhook(payload) }.not_to change { variant.reload.stock }

        expect(order.inventory_movements.reload.sole).to be_sale
      end

      it "clears the originating cart after payment succeeds" do
        create(:cart_item, cart: cart, product_variant: variant, quantity: 1)

        post_webhook(payload)

        expect(cart.cart_items.reload).to be_empty
      end

      it "enqueues an order confirmation email" do
        expect {
          post_webhook(payload)
        }.to have_enqueued_mail(OrderMailer, :confirmation)
      end
    end

    context "when the event is delivered twice (idempotency)" do
      let(:payload) do
        stripe_event(
          type: "checkout.session.completed",
          session_id: order.stripe_checkout_session_id,
          payment_status: "paid"
        )
      end

      it "finalizes inventory and sends confirmation only once" do
        expect {
          post_webhook(payload)
          post_webhook(payload)
        }.to have_enqueued_mail(OrderMailer, :confirmation).once

        expect(order.reload).to be_paid
        expect(order.inventory_movements.reload.sole).to be_sale
        expect(variant.reload.stock).to eq(8)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the local Stripe session ID was not persisted" do
      let(:order) do
        create(:order, cart: cart, stripe_checkout_session_id: nil).tap do |created_order|
          item = create(:order_item, order: created_order, product_variant: variant, quantity: 2)
          create(:inventory_movement, product_variant: variant, order_item: item, quantity: -2, reason: :reservation)
        end
      end
      let(:payload) do
        stripe_event(
          type: "checkout.session.completed",
          session_id: "cs_test_reconciled",
          payment_status: "paid",
          order_id: order.id
        )
      end

      it "finds the order through metadata, persists the session ID, and completes payment" do
        post_webhook(payload)

        expect(order.reload).to be_paid
        expect(order.stripe_checkout_session_id).to eq("cs_test_reconciled")
        expect(order.inventory_movements.reload.sole).to be_sale
        expect(variant.reload.stock).to eq(8)
      end

      it "remains idempotent when the reconciled webhook is delivered twice" do
        expect {
          post_webhook(payload)
          post_webhook(payload)
        }.to have_enqueued_mail(OrderMailer, :confirmation).once

        expect(order.reload).to be_paid
        expect(order.stripe_checkout_session_id).to eq("cs_test_reconciled")
        expect(order.inventory_movements.reload.sole).to be_sale
      end
    end

    context "when metadata conflicts with a stored Stripe session ID" do
      let(:payload) do
        stripe_event(
          type: "checkout.session.completed",
          session_id: "cs_test_conflicting",
          payment_status: "paid",
          order_id: order.id
        )
      end

      it "does not overwrite or complete the order" do
        post_webhook(payload)

        expect(order.reload).to be_pending
        expect(order.stripe_checkout_session_id).to eq("cs_test_abc123")
        expect(order.inventory_movements.reload.sole).to be_reservation
        expect(variant.reload.stock).to eq(8)
      end
    end

    context "with an unpaid checkout.session.completed event" do
      let(:payload) do
        stripe_event(
          type: "checkout.session.completed",
          session_id: order.stripe_checkout_session_id,
          payment_status: "unpaid"
        )
      end

      it "keeps the order pending and inventory reserved" do
        post_webhook(payload)

        expect(order.reload).to be_pending
        expect(order.inventory_movements.reload.sole).to be_reservation
        expect(variant.reload.stock).to eq(8)
      end

      it "does not send confirmation or clear the cart" do
        item = create(:cart_item, cart: cart, product_variant: variant, quantity: 1)

        expect { post_webhook(payload) }.not_to have_enqueued_mail(OrderMailer, :confirmation)
        expect(cart.cart_items).to include(item)
      end
    end

    context "with a checkout.session.async_payment_succeeded event" do
      let(:payload) do
        stripe_event(type: "checkout.session.async_payment_succeeded", session_id: order.stripe_checkout_session_id)
      end

      it "marks the order paid and finalizes the reservation" do
        post_webhook(payload)

        expect(order.reload).to be_paid
        expect(order.inventory_movements.reload.sole).to be_sale
        expect(variant.reload.stock).to eq(8)
      end

      it "sends confirmation and clears the originating cart" do
        create(:cart_item, cart: cart, product_variant: variant, quantity: 1)

        expect { post_webhook(payload) }.to have_enqueued_mail(OrderMailer, :confirmation).once
        expect(cart.cart_items.reload).to be_empty
      end

      it "is idempotent when delivered twice" do
        expect {
          post_webhook(payload)
          post_webhook(payload)
        }.to have_enqueued_mail(OrderMailer, :confirmation).once

        expect(order.reload).to be_paid
        expect(order.inventory_movements.reload.sole).to be_sale
        expect(variant.reload.stock).to eq(8)
      end
    end

    context "with a checkout.session.async_payment_failed event" do
      let(:payload) do
        stripe_event(type: "checkout.session.async_payment_failed", session_id: order.stripe_checkout_session_id)
      end

      it "cancels the order and releases reserved inventory" do
        post_webhook(payload)

        expect(order.reload).to be_cancelled
        expect(variant.reload.stock).to eq(10)
        expect(order.inventory_movements.pluck(:reason)).to contain_exactly("reservation", "release")
      end

      it "is idempotent when delivered twice" do
        post_webhook(payload)
        post_webhook(payload)

        expect(order.reload).to be_cancelled
        expect(variant.reload.stock).to eq(10)
        expect(order.inventory_movements.release.count).to eq(1)
      end
    end

    context "with a checkout.session.expired event" do
      let(:payload) { stripe_event(type: "checkout.session.expired", session_id: order.stripe_checkout_session_id) }

      it "cancels the order and releases reserved inventory" do
        post_webhook(payload)

        expect(order.reload).to be_cancelled
        expect(variant.reload.stock).to eq(10)
        expect(order.inventory_movements.pluck(:reason)).to contain_exactly("reservation", "release")
      end

      it "releases inventory only once when delivered twice" do
        post_webhook(payload)
        post_webhook(payload)

        expect(order.reload).to be_cancelled
        expect(variant.reload.stock).to eq(10)
        expect(order.inventory_movements.release.count).to eq(1)
        expect(response).to have_http_status(:ok)
      end

      it "does not clear the cart" do
        item = create(:cart_item, cart: cart, product_variant: variant, quantity: 1)

        post_webhook(payload)

        expect(cart.cart_items).to include(item)
      end
    end

    context "when no matching order exists" do
      let(:payload) { stripe_event(type: "checkout.session.completed", session_id: "cs_unknown") }

      it "returns 200 OK without raising" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
      end

      it "does not change any order status" do
        expect { post_webhook(payload) }.not_to change { Order.pluck(:status) }
      end
    end

    context "with an unrecognised event type" do
      let(:payload) { stripe_event(type: "payment_intent.created", session_id: "pi_123") }

      it "returns 200 OK and ignores the event" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid signature" do
      it "returns 400 Bad Request" do
        post_webhook(stripe_event(type: "checkout.session.completed", session_id: "cs_x"), signature: "invalid_sig")
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with malformed JSON" do
      it "returns 400 Bad Request" do
        allow(Stripe::Webhook).to receive(:construct_event).and_raise(JSON::ParserError)
        post_webhook("not json at all")
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
