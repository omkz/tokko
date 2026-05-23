# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bin/dev              # Start dev server (Puma + Tailwind CSS watcher via Foreman, port 3000)
bin/setup            # Install deps, prepare DB, start server
bin/setup --reset    # Same but resets DB first

# Testing
bundle exec rspec                       # Full suite
bundle exec rspec spec/models/product_spec.rb  # Single file

# Linting & security
bin/rubocop          # RuboCop (rubocop-rails-omakase style)
bin/brakeman         # Static security analysis
bin/bundler-audit    # Gem vulnerability check
bin/importmap audit  # JS dependency audit
```

## Architecture

**Stack:** Rails 8.1, PostgreSQL, Propshaft, Importmap (no bundler), Hotwire (Turbo + Stimulus), Tailwind CSS. Background jobs via Solid Queue, caching via Solid Cache, websockets via Solid Cable.

**Two distinct surfaces share one app:**

1. **Storefront** — public-facing, unauthenticated. Routes: `home#index`, `products#show`, `categories#show` (`:slug`), `collections#show` (`:slug`), `carts`, `checkouts`, `search`.
2. **Dashboard** — admin panel under `/dashboard` namespace, requires authentication. Controllers inherit from `Dashboard::BaseController` which sets `layout "dashboard"`.

**Authentication** is a custom concern (`app/controllers/concerns/authentication.rb`), not Devise. `ApplicationController` includes it globally, applying `require_authentication` to all actions. Public routes call `allow_unauthenticated_access`. Sessions are signed cookies (httponly, same_site: lax). Rate limiting is on `sessions#create` (10/3 min).

**Navigation data** (`@nav_categories`, `@nav_collections`) is loaded on every request via `ApplicationController#set_nav_data`.

**N+1 protection:** Prosopite runs in all non-production environments including tests — it will raise on detected N+1 queries.

## Domain Model

**Products** are the core entity. A product has many `ProductOption`s (e.g. Size, Color), each with `ProductOptionValue`s. `ProductVariant`s are the purchasable SKUs, linked to option values via `VariantOptionValue` (join). Variants are generated via `Product#generate_variants!` which computes the cartesian product of option values. A default variant is always created on product creation.

**Categories** are self-referential (parent/children). `Category#self_and_descendant_ids` recurses through the tree. Products belong to one category.

**Collections** are manual product groups (via `CollectionMembership`). Used for featured sets; up to 4 shown in nav via `Collection.featured_for_nav`.

**FilterGroups/FilterOptions** implement faceted filtering on the storefront. Products are tagged with `FilterOption`s via `ProductFilterOption`. `Product.filter_by_facets` accepts an array of filter slugs.

**Orders** have `OrderItem`s that capture `unit_price` at purchase time (denormalized). Status enum: `pending → paid → shipped → completed` (or `cancelled`).

**Slugs** are auto-generated on Category, Collection, FilterGroup, and FilterOption from their names.

## Testing

RSpec 8 with transactional fixtures. Prosopite raises on N+1s in tests, so always eager-load associations in specs that query multiple records. Fixtures are in `spec/fixtures/`.

## Key Conventions

- Dashboard controllers use `layout "dashboard"` (dark sidebar layout); storefront uses `layout "application"` (storefront header layout).
- Pagination via Pagy — `include Pagy::Method` in ApplicationController.
- `Current.session` / `Current.user` via `ActiveSupport::CurrentAttributes` (`app/models/current.rb`).
- Stimulus controllers live in `app/javascript/controllers/`. Importmap handles JS loading — no npm/yarn.

## Code Style & Philosophy

- **The Rails Way:** Lean heavily on native Rails features. Prefer ActiveRecord, Concerns, Callbacks, and Hotwire (Turbo/Stimulus) over heavy custom abstractions.
- **Keep It Simple:** Avoid adding architectural patterns like Service Objects or Form Objects unless a feature becomes explicitly too complex for a Model/Concern.
- **Pragmatic Controllers:** Aim for standard REST actions, but adding custom actions is acceptable if creating a new controller feels like overkill for the task.

## Code Quality & Best Practices

- **Fat Model, Skinny Controller:** Controllers should only handle routing, request parameters, status changes, and response formats. Complex business logic and data aggregation belong in Models or Concerns.
- **Database Queries & Scopes:** Never chain complex queries (e.g., `.where.not(...).order(...)`) inside controllers. Encapsulate them into descriptive model scopes or class methods.
- **Strict Eager Loading:** Because Prosopite is enabled, always explicitly eager-load associations (use `.includes`, `.preload`, or `.eager_load`) in controllers and system tests to prevent N+1 queries.
- **Pragmatic Error Handling:** Use `rescue_from` in controllers for global exceptions (like `ActiveRecord::RecordNotFound`). For business logic failures, lean on model validations and standard ActiveRecord errors (`errors.add`) instead of catching custom exceptions everywhere.
- **Consistent UI Components:** Reuse existing Tailwind classes and partials. For dynamic element updates via Turbo Streams, ensure target IDs are semantic and consistent between the view template and the controller response.