require "rails_helper"

RSpec.describe ErrorLogSubscriber do
  subject(:subscriber) { described_class.new }

  def raised_error(message = "boom")
    raise StandardError, message
  rescue StandardError => error
    error
  end

  def captured_log(method)
    logged = nil
    allow(Rails.logger).to receive(method) { |message| logged = message }
    yield
    logged
  end

  describe "#report" do
    it "writes exactly one structured log entry" do
      expect(Rails.logger).to receive(:error).once

      subscriber.report(raised_error, handled: true, severity: :error, context: {}, source: "application")
    end

    it "logs a JSON payload with the documented fields" do
      logged = captured_log(:error) do
        subscriber.report(
          raised_error("payment gateway down"),
          handled: true,
          severity: :error,
          context: { operation: "create_stripe_checkout", order_id: 123 },
          source: "application"
        )
      end
      payload = JSON.parse(logged)

      expect(payload).to include(
        "event" => "application_error",
        "error_class" => "StandardError",
        "message" => "payment gateway down",
        "handled" => true,
        "severity" => "error",
        "source" => "application",
        "context" => { "operation" => "create_stripe_checkout", "order_id" => 123 }
      )
      expect(payload["location"]).to be_a(String)
    end

    it "logs at :warn for the warning severity" do
      expect(Rails.logger).to receive(:warn)
      expect(Rails.logger).not_to receive(:error)

      subscriber.report(raised_error, handled: true, severity: :warning, context: {}, source: "application")
    end

    it "logs at :info for the info severity" do
      expect(Rails.logger).to receive(:info)
      expect(Rails.logger).not_to receive(:error)

      subscriber.report(raised_error, handled: true, severity: :info, context: {}, source: "application")
    end

    it "falls back to :error for a severity Logger does not understand" do
      logged = captured_log(:error) do
        subscriber.report(raised_error, handled: true, severity: :critical, context: {}, source: "application")
      end

      expect(JSON.parse(logged)["severity"]).to eq("error")
    end

    it "falls back to :error for a nil severity" do
      logged = captured_log(:error) do
        subscriber.report(raised_error, handled: false, severity: nil, context: {}, source: "application")
      end

      expect(JSON.parse(logged)["severity"]).to eq("error")
    end

    it "reduces non-primitive context values to their class name instead of serializing them" do
      logged = captured_log(:error) do
        subscriber.report(
          raised_error,
          handled: true,
          severity: :error,
          context: { order_id: 5, snapshot: { customer_email: "leak@example.com" }, tag: :checkout },
          source: "application"
        )
      end

      expect(JSON.parse(logged)["context"]).to eq(
        "order_id" => 5,
        "snapshot" => "Hash",
        "tag" => "checkout"
      )
    end

    it "handles a non-hash context without raising" do
      logged = captured_log(:error) do
        subscriber.report(raised_error, handled: true, severity: :error, context: nil, source: "application")
      end

      expect(JSON.parse(logged)["context"]).to eq({})
    end

    it "does not dump the full backtrace or the exception inspection" do
      logged = captured_log(:error) do
        subscriber.report(raised_error, handled: true, severity: :error, context: {}, source: "application")
      end

      payload = JSON.parse(logged)
      expect(payload).not_to have_key("backtrace")
      expect(payload["location"]).not_to be_a(Array)
      expect(payload["message"]).not_to include("backtrace")
    end
  end
end
