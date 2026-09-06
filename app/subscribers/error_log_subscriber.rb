# Rails.error subscriber: turns every reported exception into one structured
# JSON log line so container logs stay machine-searchable. Kept dependency-free
# so a real APM subscriber (Sentry/Honeybadger) can be added later without
# touching domain code.
class ErrorLogSubscriber
  # Rails.error's own severities (ActiveSupport::ErrorReporter::SEVERITIES)
  # don't line up 1:1 with Logger's method names (there's no #warning), so
  # each is mapped to the Logger method that should carry it. Anything else
  # (a nil severity, or a subscriber invoked directly with a bogus value)
  # falls back to :error rather than raising a NoMethodError.
  SEVERITY_LOG_METHODS = {
    error: :error,
    warning: :warn,
    info: :info
  }.freeze

  def report(error, handled:, severity:, context:, source: nil)
    severity = normalize_severity(severity)

    payload = {
      event: "application_error",
      error_class: error.class.name,
      message: error.message.to_s,
      handled: handled,
      severity: severity.to_s,
      source: source,
      context: safe_context(context)
    }

    location = first_application_frame(error.backtrace)
    payload[:location] = location if location

    Rails.logger.public_send(SEVERITY_LOG_METHODS.fetch(severity), payload.to_json)
  end

  private

  def normalize_severity(severity)
    severity = severity&.to_sym
    SEVERITY_LOG_METHODS.key?(severity) ? severity : :error
  end

  # Only JSON-primitive values are kept; anything else (models, structs,
  # arbitrary objects) is reduced to its class name rather than serialized,
  # so a caller accidentally passing a record can't leak its attributes.
  def safe_context(context)
    return {} unless context.is_a?(Hash)

    context.each_with_object({}) do |(key, value), safe|
      safe[key.to_s] = safe_value(value)
    end
  end

  def safe_value(value)
    case value
    when nil, String, Numeric, TrueClass, FalseClass
      value
    when Symbol
      value.to_s
    else
      value.class.name
    end
  end

  def first_application_frame(backtrace)
    return nil unless backtrace

    backtrace.find { |line| line.start_with?(Rails.root.to_s) } || backtrace.first
  end
end
