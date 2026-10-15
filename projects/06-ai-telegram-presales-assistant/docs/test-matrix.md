# Verification matrix

## Current publication snapshot — 2026-10-15

The engine/intake suite now has **42 passing tests**, superseding E1's historical
27-test count below. Added regression coverage includes requirement preservation
under reclassification, manual/no-app answers across industries, legacy pending
questions, explicit platform choice, desired-outcome field binding, and sensitive
scope review. Multi-turn native restaurant, transport, and healthcare-administration
checks passed; clear pending answers bypass AI, while open-ended turns use local
Ollama. These tests do not send Telegram messages or write customer records.

See [the current verification record](verification-record-2026-10-15.md) for the
source fingerprint and pre-publication checks. The full live journey and other
PARTIAL cases below remain unverified; historical checks were not all rerun.

## Historical baseline

Evidence update: 2026-10-14. This record summarizes tool execution results and matching test-source coverage; the documentation edit does not rerun tests. PASS applies only to the stated scope; PARTIAL identifies remaining coverage. Initial live Telegram replies are verified; the full live journey is not complete.

## Recorded execution evidence

| Evidence | Verified result | Scope |
|---|---|---|
| E1: [engine tests](../tests/engine.test.js) and [intake tests](../tests/intake.test.js) | PASS: 27 tests using the live catalog | Revised source includes complexity/FAQ, app-plus-database corrections and bypass regressions; final engine imported/published and runtime restarted |
| E2: [rollback harness](../database/tests/run_rollback_tests.sh) | PASS, including applying 003 twice | Isolated SQL assertions and rollback; preservation, privacy, leases, retry and replay |
| E3: [concurrent integration](../database/tests/run_concurrent_integration.py) | PASS in disposable `p06_verify`; all 22 pre-existing table snapshots unchanged after cleanup | Multi-session intake/claim/commit/delivery-ack races; synthetic outcomes, no Telegram sends |
| E4: Live database migration/catalog verification | PASS: existing 001/002 preserved; 003–006 applied; 25 services, 4 packages, 10 adjustments | Current database state; do not rerun unsafe original 002 |
| E5: [native subworkflow smoke tests](../scripts/smoke_n8n.py) | PASS: command, PHP 6,000–12,000 estimate, real local Ollama CRM discovery | Internal 02–08 published; actual n8n subworkflow execution, not live Telegram ingress/sending |
| E6: Custom-node/runtime/export | Persisted node installed/reloaded; runtime 00–09 active, 10–12 manual; all 13 exports validate inactive/credential-free, private env ignored | Private tunnel renewed; local/public invalid-auth checks return 403 |
| E7: Native HTTP/PostgreSQL probe | PASS: standard Webhook `lastNode`, HTTP 200 after ~1.1s with `pg_sleep(1)`; DB failure HTTP 500; ephemeral probe unpublished | Not the actual authenticated custom-intake DB-outage path |
| E8: Live customer delivery | PASS: `/start` and simple Gmail–Sheets inquiry completed first attempt; both outbox sent with Telegram IDs; 6.6s greeting / 67.5s discovery | Second reply delivery verified later in DB; user viewing it not confirmed |
| E9: Owner setup message | Telegram-confirmed synthetic setup message, no lead created | Not correlated with a real handoff ticket |
| E10: [admin checks](../scripts/test_admin.py) | PASS: create/update/approve/deactivate, audit and invalid-field rejection | Disposable database only; this run's unique synthetic records removed afterward |

## Scenario coverage

| ID | Scenario | Verified scope and remaining work | Status |
|---|---|---|---|
| T01 | Workflow/runtime/export | Import/reload verified; 00–09 active, 10–12 manual; 13 public exports validate inactive/credential-free; private env ignored. Learning-workflow preservation remains required | PASS (stated scope) |
| T02 | Migrations/catalog | E4 live versions/counts; E2 applies 003 twice and preserves legacy fixtures. Original 002 must not be rerun | PASS (stated scope) |
| T03 | Commands | E1 command bypass checks, E5 native command smoke, and live `/start` reception/reply pass | PASS (tested commands) |
| T04 | Intake exclusions | E1 bots/groups/edits/oversize checks; E2 unsupported and oversized SQL handling. Live webhook transport not tested | PASS (unit/SQL) |
| T05 | Duplicate intake | E2 duplicates; E3 concurrent same-update and alternate-update ingestion produces one message/inbox | PASS (database) |
| T06 | Ordering/isolation | E3 three chats × three ordered decisions, concurrent claims/commits and ordered synthetic delivery acknowledgements | PASS (database) |
| T07 | Strict extraction | E1 invalid JSON/types/extra fields/bounds checks; E5 real model discovery. Live repair/outage paths not established | PARTIAL |
| T08 | Injection/confidence | E1 injection/sensitive-scope checks and confidence 0.74 fallback pass. Exhaustive boundary/adversarial coverage not established | PARTIAL |
| T09 | Discovery/confirmation | E1 app replacement preserves database correction across turns, producing PHP 14,000–27,000; commercial/sensitive requests cannot bypass review; earlier memory/confirmation cases pass | PASS (tested source cases) |
| T10 | Simple/intermediate prices | Simple PHP 6,000–12,000 passes E1/E5; two-app `multi_step` selects intermediate with PHP 15,000 minimum in E1. Full live intermediate quote remains untested | PASS (unit/native scope) |
| T11 | Narrow CRM | E1 PHP 10,000–18,000 and reverse-direction rejection; E5 real Ollama CRM discovery. Complete live chat path pending | PASS (unit/discovery smoke) |
| T12 | Telegram FAQ | E1 FAQ PHP 15,000–25,000 and non-FAQ handoff pass; live FAQ journey not established | PASS (unit scope) |
| T13 | Pricing boundaries | E1 database add-on PHP 14,000–27,000, missing-service and lowered-ceiling fallback; E2 approval filtering. Full boundary/billing matrix remains | PARTIAL |
| T14 | Commercial safeguards | E1 app-correction flow cannot bypass commercial/sensitive checks; rush, discount/final-quote and service-only regressions pass. Exhaustive live scenarios remain | PARTIAL |
| T15 | Contact/consent | E1 consent gating; E2 contact marker/presence, stored consent, withdrawal and private-setting exclusion | PASS (unit/SQL) |
| T16 | Reset/delete | E1 reset/handed-off behavior; E2 canonical consent/reset and deletion-review ticket. No actual erasure claimed | PASS (unit/SQL request semantics) |
| T17 | Qualification | E1 hot scoring preserves existing handoff reason and raises priority to high; E2 approved/unapproved persistence. Full band-boundary matrix remains | PARTIAL |
| T18 | Owner handoff | Private owner configured; synthetic setup message Telegram-confirmed, no lead created. No real handoff ticket correlation yet | PARTIAL |
| T19 | Atomic rollback | E2 failed-commit rollback; harness passes with 003 applied twice | PASS (SQL) |
| T20 | Lease/retry fencing | E2 stale-token/reclaim/backoff/five-attempt assertions; E3 concurrent claim/commit fencing. Inbox 600s, sender 120s | PASS (database) |
| T21 | Delivery classification | E1 typed outcome classification; E2 synthetic success/429/expiry; E3 retry-delay boundaries. Real Telegram API failures not exercised | PARTIAL |
| T22 | Replay safety | E2 duplicate acknowledgement, expired-send quarantine and guarded replay assertions; no actual uncertain network send replayed | PASS (database protocol) |
| T23 | Dependency outages | Real Ollama discovery passes; comprehensive model/database/network outage runs not established | PARTIAL |
| T24 | Admin/privacy/export | E10 administrator mutation checks pass; SQL privacy and credential sanitization pass; 13 inactive credential-free exports validated and private env ignored. Full operator CLI coverage remains | PARTIAL |
| T25 | Live Telegram journey | E8 greeting/discovery completed first attempt and sent with Telegram IDs. Full estimate → consent → contact → ticket-correlated handoff and screenshots pending | PARTIAL |
| T26 | Custom-node installation | Persisted `/home/node/.n8n/custom/P06TelegramIntake.node.js` installed, imported and reloaded; live initial messages processed | PASS (installation/reload) |
| T27 | Durable HTTP ACK | E7 standard native `lastNode`/PostgreSQL timing and failure probe PASS; actual authenticated custom-intake database-outage path unverified | PARTIAL |
| T28 | Publish/restart/tunnel | Runtime 00–09 active, 10–12 manual; custom node reloaded; tunnel renewed privately; initial live delivery verified. Final revised engine imported/published and runtime restarted | PASS (stated runtime scope) |
| T29 | Webhook authentication/secrecy | Unit valid/forged-secret checks and local/public invalid-auth 403 checks pass. Do not infer authenticated custom-intake DB-outage coverage | PASS (tested auth checks) |

E3 verifies cleanup in `p06_verify`, not a claim that live business tables were untouched by deployment migrations. Its Telegram delivery outcomes are simulated database acknowledgements. E1's `lastNode` assertion checks configuration. E7 adds real standard-Webhook HTTP timing, but does not exercise the authenticated custom intake under database outage.

Keep dated sanitized logs with source revision/environment; do not invent missing run metadata. Migration 006 application and final engine deployment are complete. The user reported only the greeting at the time asked; later DB/Telegram-ID evidence establishes sending of the second reply, not that it was read. Complete live estimate/consent/contact/handoff and screenshots before claiming that journey passed.
