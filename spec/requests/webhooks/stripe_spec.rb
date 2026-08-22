require "rails_helper"

RSpec.describe "Webhooks::Stripe", type: :request do
  def stripe_event(
    type:,
    session_id:,
    event_id: "evt_test_123",
    payment_status: nil,
    order_id: nil
  )
    session = { "id" => session_id }
    session["payment_status"] = payment_status if payment_status
    session["metadata"] = { "order_id" => order_id.to_s } if order_id

    {
      "id" => event_id,
      "type" => type,
      "data" => { "object" => session }
    }.to_json
  end

  def post_webhook(payload, signature: "valid_sig")
    post webhooks_stripe_path,
      params: payload,
      headers: { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
  end

  before do
    allow(Stripe::Webhook).to receive(:construct_event) do |payload, signature, _secret|
      raise Stripe::SignatureVerificationError.new("bad sig", signature) if signature == "invalid_sig"

      JSON.parse(payload)
    end
  end

  it "persists and enqueues a supported event" do
    payload = stripe_event(
      type: "checkout.session.completed",
      session_id: "cs_test_123",
      payment_status: "paid",
      order_id: 42
    )

    expect { post_webhook(payload) }.to change(StripeWebhookEvent, :count).by(1)

    event = StripeWebhookEvent.sole
    expect(event).to have_attributes(
      stripe_event_id: "evt_test_123",
      event_type: "checkout.session.completed",
      stripe_session_id: "cs_test_123",
      payment_status: "paid",
      metadata_order_id: 42,
      processed_at: nil
    )
    expect(ProcessStripeWebhookEventJob).to have_been_enqueued.with(event.id)
    expect(response).to have_http_status(:ok)
  end

  it "persists duplicate deliveries once" do
    payload = stripe_event(type: "checkout.session.expired", session_id: "cs_test_123")

    expect {
      post_webhook(payload)
      post_webhook(payload)
    }.to change(StripeWebhookEvent, :count).by(1)

    expect(response).to have_http_status(:ok)
  end

  it "does not enqueue an already processed event" do
    StripeWebhookEvent.create!(
      stripe_event_id: "evt_test_123",
      event_type: "checkout.session.expired",
      stripe_session_id: "cs_test_123",
      processed_at: Time.current
    )
    payload = stripe_event(type: "checkout.session.expired", session_id: "cs_test_123")

    expect { post_webhook(payload) }.not_to have_enqueued_job(ProcessStripeWebhookEventJob)

    expect(response).to have_http_status(:ok)
  end

  it "ignores unsupported event types" do
    payload = stripe_event(type: "payment_intent.created", session_id: "pi_123")

    expect { post_webhook(payload) }
      .not_to change(StripeWebhookEvent, :count)
    expect(ProcessStripeWebhookEventJob).not_to have_been_enqueued
    expect(response).to have_http_status(:ok)
  end

  it "rejects an invalid signature without persisting or enqueueing" do
    payload = stripe_event(type: "checkout.session.completed", session_id: "cs_test_123")

    expect { post_webhook(payload, signature: "invalid_sig") }
      .not_to change(StripeWebhookEvent, :count)
    expect(ProcessStripeWebhookEventJob).not_to have_been_enqueued
    expect(response).to have_http_status(:bad_request)
  end

  it "rejects malformed JSON" do
    allow(Stripe::Webhook).to receive(:construct_event).and_raise(JSON::ParserError)

    post_webhook("not json at all")

    expect(response).to have_http_status(:bad_request)
    expect(StripeWebhookEvent.count).to be_zero
    expect(ProcessStripeWebhookEventJob).not_to have_been_enqueued
  end
end
