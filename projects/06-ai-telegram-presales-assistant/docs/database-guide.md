# Database guide

Use [CONTRACT.md](../database/CONTRACT.md) for function signatures and [003_runtime.sql](../database/003_runtime.sql) for implementation. Functions run with the caller's privileges (`SECURITY INVOKER`); the trusted worker needs explicit schema, function and table access. Telegram users must never receive that access.

| Records | Purpose |
|---|---|
| `customers`, `conversations`, `conversation_state`, `chat_sessions` | Identity, current conversation, requirements and consent |
| `messages`, `processed_updates`, `chat_message_receipts` | Redacted history and canonical update/message deduplication |
| `inbox_jobs`, `outbox_jobs`, `dead_letter_events` | Durable work, delivery and recovery |
| `services`, `service_packages`, `pricing_adjustments`, `business_policies`, `faqs` | Active, approved business configuration |
| `estimates`, `leads`, `handoff_tickets`, `audit_events`, `consent_events` | Traceable business decisions and consent evidence |
| `schema_migrations`, `runtime_settings` | Applied versions and private operator configuration |

## Migration order

1. Verified local state: migrations 001–006 are applied, preserving the original 001/002 data. All six migrations are included in `database/`; inspect the ledger before applying missing versions.
2. For a fresh installation, use `scripts/migrate.py` to apply numbered migrations in order. Back up an existing demo database before updating it and stop on errors.
3. Verify recorded versions, approved rows, preservation of operator edits, and service-only routing before activation. The original catalog contains 25 services, 4 packages and 10 adjustments; legitimate custom/inactive records can make database counts larger.

Do not rerun the original 002 migration: its FAQ inserts lack question uniqueness and can duplicate FAQs. Do not erase the ledger to force a rerun. Migration 004 preserves existing edited records and inserts missing FAQ questions; it does not remove legacy duplicates.

The [migration runner](../scripts/migrate.py) reads `schema_migrations` and skips recorded versions. It scans the project's `database/` directory. Its Docker target assumes the documented Compose container and database names. Do not run it blindly on an existing database.

## Worker protocol

`accept_update(jsonb)` durably accepts supported private text and recognizes duplicates. The SQL also accepts the trusted flat adapter envelope. `claim_inbox()` returns a catalog snapshot, canonical consent, state and lease token. `commit_decision(update_id, token, decision)` commits all business writes and the reply job together. Successful duplicate commits return `duplicate`; stale/expired claims are rejected.

Latest ingress contract: the custom Telegram trigger uses `responseMode: lastNode`, and successful intake ACK follows the durable `accept_update` result through 02. Database errors must not be hidden behind early success. Unit tests for `lastNode` and synthetic authentication pass; database duplicate/concurrency tests pass. Local/public invalid-auth checks return 403. A standard native Webhook/PostgreSQL probe returned 200 after ~1.1s with a one-second DB sleep and 500 on failure, then was unpublished. This does not verify the authenticated custom-intake database-outage path. Outbound replies still use native Telegram sending and the separate outbox protocol.

`fail_inbox()` schedules 5/10/20/40-second retries, with a five-attempt limit or immediate dead letter for nonretryable work. Inbox leases last 600 seconds; sender leases last 120 seconds. Expired inbox claims can be reclaimed. The builder's current orchestrator does not explicitly wire every exception to this function; test failure propagation rather than assuming coverage.

`claim_outbox()` leases ordered delivery work. `finish_outbox()` records a positive Telegram message ID for confirmed success; it also supports `retry`, `dead_letter` and `unknown`. SQL includes a JSON outcome adapter and both `id`/`outbox_id` claim fields for the builder. Unknown/expired sends are quarantined, not automatically resent. A blocked earlier job can hold later messages.

Only operators may replay dead letters. Inspect the delivery record first; uncertain outbox replay requires explicit acknowledgement of possible duplicate delivery. Completed inbox work and sent replies cannot be replayed. Never clear queues or rewrite sent status merely to make a demo look successful.

The database contract retains legacy support for a package reference. The current application must emit `service_code` only, following 005; database compatibility does not authorize package calculations.

Teaching note: a transaction makes a decision all-or-nothing. A lease limits who may finish it. The rollback harness passed, including applying 003 twice. Concurrent multi-session tests passed in `p06_verify`, with all 22 pre-existing table snapshots unchanged after cleanup. These are database checks, not live Telegram delivery evidence.

Migration `006_runtime_policy_alignment.sql` is applied in the local demo. It aligns metadata to the 24-field extraction schema and documents code-enforced conservative scope/scoring defaults without granting business approval or changing approved rates/weights.
