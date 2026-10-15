# Phase 3 — Database and Catalog

PostgreSQL is the authoritative source for services, packages, prices, FAQs,
business policies, conversation state, estimates, leads, handoffs, and audit
events. The language model must never be treated as a pricing database.

## Migrations

- `001_core_presales_schema.sql` creates the normalized operational schema,
  status checks, foreign keys, indexes, and idempotency records.
- `002_catalog_and_rules.sql` seeds synthetic services, packages, adjustments,
  policies, and FAQs.

Migrations are safe to re-run because they use conflict-aware definitions and
seed records keyed by stable codes.

## Verification

Run the smoke test after applying both migrations. It checks table existence,
catalog counts, and the approved confidence and estimate-ceiling policies.
