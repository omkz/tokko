# Production only: code isn't reloaded between requests in production, so
# this registers exactly once per boot.
Rails.error.subscribe(ErrorLogSubscriber.new) if Rails.env.production?
