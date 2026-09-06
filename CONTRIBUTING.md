# Contributing to Tokko

Thanks for your interest in improving Tokko.

## Development setup

```bash
git clone https://github.com/omkz/tokko.git
cd tokko
bin/setup
```

See [README.md](README.md) for details on what `bin/setup` does, plus optional Stripe development setup.

## Before opening a PR

```bash
RAILS_ENV=test bin/rails tailwindcss:build
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

All of these should pass before you open a PR — they're the same checks CI runs.

## Project direction

Tokko follows a few deliberate engineering preferences:

- **Rails Majestic Monolith** — one app, not a constellation of services.
- Prefer Rails/Active Record conventions over custom abstractions.
- **HTML/Hotwire-first** — reach for Turbo/Stimulus before a heavier JS approach.
- Preserve database invariants (validations, constraints, transactions) — don't paper over them in application code.
- Prefer small, focused changes over sweeping ones.
- Avoid introducing service objects, form objects, or other framework layers unless a feature genuinely outgrows a Model/Concern.
- Bug fixes should come with a regression test.

## Pull requests

- Keep PRs focused on one change.
- Explain the motivation in the PR description — what problem this solves, not just what changed.
- Include tests where appropriate.
- Avoid unrelated formatting or refactoring in the same PR — it makes review harder and obscures the actual change.
