class Webhooks::StripeController < ApplicationController
  SUPPORTED_EVENT_TYPES = %w[
    checkout.session.completed
    checkout.session.async_payment_succeeded
    checkout.session.async_payment_failed
    checkout.session.expired
  ].freeze

  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token

  def create
    payload   = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
    return head :ok unless SUPPORTED_EVENT_TYPES.include?(event["type"])

    session = event["data"]["object"]
    stripe_webhook_event = StripeWebhookEvent.create_or_find_by!(stripe_event_id: event["id"]) do |record|
      record.event_type = event["type"]
      record.stripe_session_id = session["id"]
      record.payment_status = session["payment_status"]
      record.metadata_order_id = session.dig("metadata", "order_id").presence
    end

    ProcessStripeWebhookEventJob.perform_later(stripe_webhook_event.id) unless stripe_webhook_event.processed?

    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end
end
