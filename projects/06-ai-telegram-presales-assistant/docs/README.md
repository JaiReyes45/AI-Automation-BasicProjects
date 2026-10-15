# Project06 documentation

## Current review — 2026-10-15

Start with [local setup](setup.md), [the latest verification record](verification-record-2026-10-15.md), and [the status roadmap](status-roadmap.md).
The engine/intake suite now has **42 passing tests**. Native multi-turn restaurant,
transport, and healthcare-administration checks passed, using local Ollama for
open-ended turns. Clear pending-question answers can bypass AI after safety checks.
All 13 repository workflow exports are inactive and credential-free. The full
live estimate-to-handoff acceptance and final screenshots remain pending.

The dated narrative below is historical evidence, not a statement of the current
test count or publication status. Original Phase 1/2 notes remain design history;
prefer the current setup guide, source, and verification record when they differ.

## Historical snapshot

Snapshot: 2026-10-14. This is a synthetic portfolio pre-sales assistant, not a live commercial quotation service. Tool execution results are recorded in the [test matrix](test-matrix.md). Initial live Telegram delivery is verified; the full estimate → consent → contact → handoff journey and screenshots remain pending. This is not production certification.

| Read this | For |
|---|---|
| [Architecture and lifecycle](architecture-lifecycle.md) | Responsibilities, all 13 workflows, durable processing |
| [Database guide](database-guide.md) | Migrations, records, claims, recovery |
| [Catalog and pricing](catalog-pricing.md) | Original rate card, service-range estimates, approved scoring |
| [Telegram and tunnel setup](telegram-setup.md) | Local preparation and later activation |
| [Client usage](client-usage.md) | Commands and synthetic conversation |
| [Privacy and administration](privacy-admin.md) | Consent, reset, deletion review, owner handoff |
| [Troubleshooting](troubleshooting.md) | Symptoms and safe diagnostic checks |
| [Test matrix](test-matrix.md) | Pending verification and evidence requirements |
| [Dated verification record](verification-record-2026-10-14.md) | Final source fingerprint, executed checks and remaining acceptance |
| [Six-minute demo](demo-checklist.md) | Narration and screenshot checklist |

Latest approved decisions: calculate preliminary estimates from approved service ranges only; packages remain informational. Scoring weights and handoff to the user's own Telegram account are approved. The owner ID stays in private database configuration. Approval of that destination is not evidence that a notification was delivered.

Latest evidence: 27 unit/intake tests PASS using the live catalog; rollback, concurrent database and native command/estimate/Ollama smoke checks PASS. All 13 public exports validate as inactive and credential-free; private environment files are ignored. Runtime 00–09 are active and 10–12 are manual. The custom encrypted-credential intake node is persisted/reloaded, the tunnel renewed privately, and local/public invalid-authentication checks return 403. Native Telegram sending is retained. The final revised engine was imported/published and n8n restarted; migration 006 is applied. Disposable-database admin create/update/approval/deactivation/audit and invalid-field tests also passed.

A temporary standard native Webhook (`lastNode`) plus PostgreSQL probe passed: HTTP 200 took about 1.1 seconds after `pg_sleep(1)`, and database failure returned HTTP 500. The probe was unpublished afterward. This verifies the standard `lastNode` mechanism, not an authenticated custom-intake database-outage scenario.

Live `/start` and a simple Gmail–Sheets inquiry both completed on their first attempt; both outbox replies are `sent` with confirmed Telegram message IDs. Observed latency was 6.6 seconds for the greeting and 67.5 seconds for AI discovery. The user had reported seeing only the greeting; later database verification confirms the second reply was sent, not that the user saw it.

The private owner setup test message has Telegram delivery confirmation, but it was not tied to a real handoff ticket and created no lead. A correlated handoff notification remains to be verified.

Keep the existing learning workflow inactive and preserved. Treat `.runtime/` staging as private. Never publish credentials, private webhook URLs/paths or authentication secrets, owner identifiers, database dumps, private staging, customer-specific rendered prompts, or raw model responses containing customer data. Generic prompt templates are part of the reviewed source exports. Customer replies come from approved templates/catalog content and validated facts. No Git push or public publication has been performed.

Implementation references: [engine](../runtime/engine.js), [workflow builder](../scripts/build_workflows.py), [database contract](../database/CONTRACT.md), [catalog completion](../database/004_catalog_completion.sql), and [service estimate policy](../database/005_service_estimate_policy.sql). These guides reflect the latest service-only decision even where the older database contract still permits package references.
