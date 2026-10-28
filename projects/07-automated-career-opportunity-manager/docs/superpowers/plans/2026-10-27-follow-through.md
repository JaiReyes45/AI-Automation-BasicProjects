# CareerFlow Follow-through Implementation Plan

> **For agentic workers:** Use Superpowers execution with independent module ownership, test-first changes, and final integration review. Track steps using checkboxes.

**Goal:** Turn imported career emails into discoverable applications, actionable tasks, desktop alerts and evidence-backed interview scheduling.
**Architecture:** Existing local services; durable PostgreSQL state; n8n remains Google transport. Domain extraction, notifications and mailbox synchronization have separate modules. Flutter presents projections rather than asking the model to infer state.
**Tech Stack:** Flutter/Dart, Python, PostgreSQL, n8n, Ollama, Windows PowerShell notification helper.
**Spec:** ../specs/2026-10-27-follow-through-design.md

## Global constraints
Preserve volumes and personal data. No secret material in Git. Historical reads and Gmail label mutations have independent authorization. Employer sends/invitations require reviewed confirmation. Automatic holds have no guests. Use Asia/Manila for display; preserve explicit timezones. Never infer hiring probability or a submission from a saved job listing.

## Review focus
Duplicate and out-of-order mail; two roles at one company; quoted/negated requests; date/timezone ambiguity; expired synchronization/notification leases. Each owner must add regression coverage for its portion.

## Tasks
1. Mail capture (`crm/mail_sync.py`, Gmail workflow builder, mail normalization and tests): durable runs/pages/cursor, bounded recovery/backfill, direction and reply headers. Check failure-before-success and replay/resume behavior.
2. Engagement (`crm/engagement.py`, migrations and tests): request extraction, unmatched tasks, source evidence, ownership, correction preservation and sent-reply reconciliation.
3. Notifications (`crm/notifications.py`, Windows helper and tests): transactional intents, delivery leases, retries, read/snooze, scoped pairing and closed-tab desktop delivery.
4. Matching/calendar (classifier/matching, organizer, Calendar workflow and tests): independent matching evidence, proposal extraction, stable private holds and update/cancel lifecycle, preserve reviewed sends.
5. Flutter (`lib/data`, `lib/ui`, widget tests): Today, action inbox, linked tasks, honest scheduling states, quick capture, notification settings. Preserve colors/profile/search.
6. Retrieval (`crm/assistant.py` and tests): deterministic workspace search and action facts, citations/completeness, useful availability proposals, no model execution.
7. Integration and release: migrations, authenticated routes, regression suites, synthetic database verification, production web build, scoped Docker redeployment, workflow publication preserving credentials, browser check, tracker and guides.

Each task: write meaningful failing test; observe RED; implement; observe GREEN and relevant existing regressions; record evidence. Final review addresses cross-module contracts and safety.

## Execution ledger
- Started October 27. Approved direction and Windows alerts recorded.
- Ruling: the Windows workspace is the existing isolated authoring mirror; its Git repository has no commits. Canonical WSL main is clean at 2eae62f. Edit/test the mirror, then integrate only reviewed source on a canonical feature branch; do not reset either workspace or copy secrets.
- Interfaces: GET `/api/crm/today` returns `needs_response`, `waiting`, `upcoming`, `review`, `handled`, `notifications`, `coverage`; GET notifications returns `items`. Tasks retain existing `id/version/application_id/title/category/status/due_on`, add `actor/source_account/source_message_id/evidence/request_kind/due_at`. Unmatched tasks have null application_id. Scoped notification pairing and commands must not expose general workflow authorization.
- October 28 checkpoint: module implementations integrated; 30 widget tests and rollback-only PostgreSQL follow-through acceptance pass. Calendar workflow conditional upsert/readback checks pass. Final regression, backup, build/deployment and actual helper pairing remain pending.
- October 28 deployment checkpoint: restore-tested private backup, live Gmail capture and Calendar reads, notification helper pairing/startup and acknowledged desktop test complete. Independent review findings fixed and re-reviewed. 97 Python and 30 Flutter tests pass, static analysis clean; final rebuilt client and signed-in acceptance pending. No employer reply or invitation used as a test.
- October 28 final deployment: rebuilt CRM/web healthy; refreshed browser retains authenticated access and renders Today. Connections shows healthy capture through 15:16 Manila and acknowledged Windows alerts. Final Gmail export published after restart. Deployed rollback-only suites and source regression checks pass; tracker and guides updated. Genuine employer progression and external sends retain the documented field-acceptance boundary.
