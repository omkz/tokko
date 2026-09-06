# Tokko — Rails E-Commerce Starter Kit

[![CI](https://github.com/omkz/tokko/actions/workflows/ci.yml/badge.svg)](https://github.com/omkz/tokko/actions/workflows/ci.yml)

Tokko is an open-source Rails e-commerce starter kit built with Rails 8.1, PostgreSQL, Hotwire, and Stripe. It includes the core commerce building blocks — products with variants, Stripe checkout, customer accounts, discount coupons, inventory tracking, and an admin dashboard — as a starting point for your own store.

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

- Ruby version from [`.ruby-version`](.ruby-version) (currently Ruby 4.0.3)
- PostgreSQL 14+, running locally

For Stripe checkout/webhook development (optional — see [Stripe development](#stripe-development) below):
- A [Stripe](https://stripe.com) account
- [Stripe CLI](https://docs.stripe.com/stripe-cli)

## Quick Start

Make sure PostgreSQL is running locally, then:

```bash
git clone https://github.com/omkz/tokko.git
cd tokko
bin/setup
```

`bin/setup` will:
- install gems, if needed
- initialize local Rails credentials, if `config/credentials.yml.enc` doesn't exist yet
- prepare the development database
- run development seed data on a new database
- clear temp/log files
- start `bin/dev`

Use `bin/setup --skip-server` to run setup without starting the development server.

`bin/setup --reset` is also available, but it's **destructive**: it deletes and recreates the development database. Don't reach for it as a routine troubleshooting step.

## Configuration

Rails application credentials are used only for Stripe secrets. `config/master.key` decrypts them and must never be committed — a fresh `bin/setup` creates its own credentials/key pair automatically, so there's usually nothing to do here for local development.

To add Stripe credentials yourself:

```bash
bin/rails credentials:edit
```

```yaml
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...
```

(These are placeholders — never commit real credentials.)

Production database and SMTP configuration use environment variables instead of credentials — see [`docs/operations/deployment.md`](docs/operations/deployment.md) for deployment details.

## Development

```bash
bin/dev          # Start server + Tailwind watcher (port 3000)
```

**Development-only demo account** (created by `db/seeds/development.rb`):

```
Email:    admin@tokko.com
Password: password
```

This account is created only by the development seed and is never created in production.

Log in at `http://localhost:3000/dashboard`.

### Stripe development

Stripe is optional until you want to exercise checkout or webhook flows. `bin/dev` does not start the Stripe CLI.

1. Add test Stripe credentials:
   ```bash
   bin/rails credentials:edit
   ```
   ```yaml
   stripe:
     secret_key: sk_test_...
     webhook_secret: whsec_...
   ```
2. In a separate terminal, forward webhook events:
   ```bash
   stripe listen --forward-to localhost:3000/webhooks/stripe
   ```
   Copy the webhook signing secret it prints into `stripe.webhook_secret` above.

Without Stripe credentials configured, checkout will not complete — everything else in the storefront and dashboard works fine on its own.

## Testing

A clean checkout needs Tailwind CSS built once before request/system specs that render layouts:

```bash
RAILS_ENV=test bin/rails tailwindcss:build
bundle exec rspec                              # Full suite
bundle exec rspec spec/models/product_spec.rb  # Single file
```

**Code quality:**

```bash
bin/rubocop       # Linting
bin/brakeman      # Security audit
bin/bundler-audit # Gem vulnerability check
```

## Deployment

This project includes a [Kamal](https://kamal-deploy.org) configuration. Update `config/deploy.yml` with your server IP, image registry, domain, mail settings, and PostgreSQL connection (`DB_HOST`/`DB_PORT`/`DB_USERNAME`), then set the production database password and deploy:

```bash
export TOKKO_DATABASE_PASSWORD='...'

bin/kamal config   # sanity-check the resolved configuration locally
bin/kamal setup    # first deploy
```

`RAILS_MASTER_KEY` (from `config/master.key`) is read from `.kamal/secrets` automatically by Kamal 2 whenever a command needs it — there's no separate push step. Don't commit real secrets; `.kamal/secrets` only contains variable references, and actual values come from your shell environment or secret manager.

For subsequent deploys:

```bash
bin/kamal deploy
```

See [`docs/operations/deployment.md`](docs/operations/deployment.md) for PostgreSQL provisioning, healthcheck details, mail/SMTP environment variables, SSL options, and a post-deploy verification checklist.

Production does not create a default administrator. Bootstrap the first owner explicitly; see [`docs/operations/deployment.md`](docs/operations/deployment.md#first-owner).

### Backup and Restore

See [`docs/operations/backup-and-restore.md`](docs/operations/backup-and-restore.md) for the disaster recovery runbook — what to back up, how to verify a backup, and how to restore production.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
