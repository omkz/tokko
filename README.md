# Tokko — Rails E-Commerce Starter Kit

A production-ready e-commerce starter kit built with Rails 8.1. Ships with everything you need to launch an online store: products with variants, Stripe checkout, customer accounts, discount coupons, inventory tracking, and a full-featured admin dashboard.

## Features

**Storefront**
- Product catalog with variants, options, and faceted filtering
- Category and collection pages
- Full-text product search
- Cart and Stripe Checkout (with coupon support)
- Customer accounts — order history, saved addresses, wishlist
- Magic link authentication (no password required)
- SEO-ready — meta tags, Open Graph, slug-based URLs with redirect history

**Dashboard**
- Product management — create products, generate variants from options (Size × Color)
- Inventory tracking with movement history
- Order management with status flow (`pending → paid → shipped → completed`)
- Coupon/discount codes — percentage or fixed, with expiry and usage limits
- Collections and categories management
- User roles — Owner, Admin, Staff

**Technical**
- Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind CSS
- Stripe Checkout + webhook handling
- Background jobs via Solid Queue, caching via Solid Cache
- FriendlyId slug URLs with history (301 redirects when slugs change)
- N+1 protection via Prosopite in development and test
- RSpec test suite

## Requirements

- Ruby 4.0+
- PostgreSQL 14+
- Node.js (for Tailwind CSS watcher)
- A [Stripe](https://stripe.com) account

## Quick Start

```bash
git clone <your-repo-url> my-store
cd my-store
bin/setup
```

`bin/setup` installs dependencies, creates and seeds the database, and starts the server at `http://localhost:3000`.

To reset the database and start fresh:

```bash
bin/setup --reset
```

## Configuration

All secrets are managed via Rails credentials. Open the credentials file:

```bash
bin/rails credentials:edit
```

Add the following:

```yaml
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...

smtp:
  user_name: your@email.com
  password: your-smtp-password
```

**Stripe webhook** — in development, use the Stripe CLI to forward events:

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

Copy the webhook signing secret it prints and add it to credentials as `stripe.webhook_secret`.

## Development

```bash
bin/dev          # Start server + Tailwind watcher (port 3000)
```

**Default admin account** (created by seed):

```
Email:    admin@tokko.com
Password: password
```

Log in at `http://localhost:3000/dashboard`.

## Testing

```bash
bundle exec rspec                              # Full suite
bundle exec rspec spec/models/product_spec.rb # Single file
```

**Code quality:**

```bash
bin/rubocop       # Linting
bin/brakeman      # Security audit
bin/bundler-audit # Gem vulnerability check
```

## Deployment

This project includes a [Kamal](https://kamal-deploy.org) configuration. Update `config/deploy.yml` with your server IP and image registry, then:

```bash
kamal setup   # First deploy
kamal deploy  # Subsequent deploys
```

Set `RAILS_MASTER_KEY` on your server (found in `config/master.key`):

```bash
kamal env push
```

## Roadmap

- [ ] Role-based authorization (Pundit)
- [ ] Audit log for admin actions (PaperTrail)
- [ ] Store settings (name, logo, currency)
- [ ] Custom error pages (404, 500)
- [ ] Product reviews
- [ ] Shipping rate configuration

## License

MIT
