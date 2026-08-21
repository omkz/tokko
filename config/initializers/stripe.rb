Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
Stripe.max_network_retries = 2
