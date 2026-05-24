require "rails_helper"

RSpec.describe "Webhooks::Stripe", type: :request do
  let(:order) { create(:order, stripe_checkout_session_id: "cs_test_abc123") }

  def stripe_event(type:, session_id:)
    {
      "type" => type,
      "data" => {
        "object" => {
          "id" => session_id
        }
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
    context "with a valid checkout.session.completed event" do
      let(:payload) { stripe_event(type: "checkout.session.completed", session_id: order.stripe_checkout_session_id) }

      it "returns 200 OK" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
      end

      it "marks the order as paid" do
        post_webhook(payload)
        expect(order.reload.status).to eq("paid")
      end

      it "enqueues an order confirmation email" do
        expect {
          post_webhook(payload)
        }.to have_enqueued_mail(OrderMailer, :confirmation)
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
