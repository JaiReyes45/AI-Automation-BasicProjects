# Status and teaching milestones

## General manual-setup discovery — 2026-10-14

Fixed the remaining no-app loop outside inventory: an explicit answer to the
apps question sets `current_app_status=none` and preserves the stated manual
process, separately from the future platform. Clear pending-question answers
are handled after preflight safety checks without an AI request. Mixed or
ambiguous replies still use normal extraction. `/reset` clears this state.

Restaurant order tracking asks staff entry versus customer-submitted ordering;
staff entry proceeds to platform selection, while customer-submitted ordering
needs human scope review. Other manual tasks ask for the desired outcome before
software selection when that outcome is not already known. Inventory retains
its recording-method/target-platform flow. This is process-based discovery, not
a promise to support every industry or certify regulated workflows. Existing
medical/patient-record safeguards still require human review; ordinary clinic
office-supply administration is not automatically treated as patient data.

42 engine/intake tests pass, including the exact restaurant reply, legacy
question state, no-app answers across tasks, transport, clinic administration,
education, retail and construction examples, ambiguous-answer guards and reset.
A four-turn installed-workflow restaurant test passed (request, no apps, staff
entry, Google Sheets), using local Ollama for open-ended turns. Deterministic
estimate regression also passed. These probes use synthetic data and do not
send Telegram messages or insert customer records. Workflows 03/05 were patched
with private pre-change backups; prices and credentials were unchanged.
The multi-turn transport probe also passed through installed workflows with
local Ollama. Local and public health checks returned HTTP 200 after deployment.

The initial healthcare-admin probe caught model-driven category drift during
follow-up answers. Targeted desired-outcome answers now update that field only,
after validation/safety review. Exact common platform selections use a scoped
parser, preserving the existing task/category and avoiding an unnecessary model
call. Mixed instructions and app replacement lists remain on the normal path.
An additional regression test covers a model attempting to reclassify clinic
office supplies as CRM. This does not lock classification for every free-form
message or guarantee universal natural-language understanding. The corrected
multi-turn healthcare-admin probe subsequently passed on the deployed runtime.

## Contextual inventory discovery — 2026-10-14

Workflows 03 and 05 now preserve explicit manual-recording answers and ask
inventory-specific recording-method and target-platform questions. Notebook,
paper and no-app answers are not software names. An unspecified inventory-app
choice requests human platform scoping rather than inventing a product or price.
Generic app questions no longer mention email; chatbot questions ask about the
channel. Known apps skip the inventory recording-method question. Existing
conversations at the old apps question can answer `notebook` without resetting.

35 engine/intake tests pass, including manual-answer progression, legacy-state
compatibility, known-app skipping, safety checks and reset. A real local Ollama
inventory-description integration test and a separate real-model `notebook`
answer test passed on the installed workflows.
Private pre-change exports of workflows 03 and 05 were retained. Only those
workflows were republished; no customer records, prices or credentials changed.
Public workflow exports were regenerated and checked. Local Ollama remains in
use; this is a targeted discovery improvement, not general free-form reasoning
or a speed optimization. Complete Telegram acceptance remains a user check.

## Memory fix — 2026-10-14

Removed the destructive requirement reset on AI service reclassification. New
non-null extracted facts still merge, explicit corrections still apply, and
changed requirements invalidate the old estimate. `/reset` remains the explicit
working-requirements reset. No fast-answer handling, model change or speed tuning
was introduced. Previously erased answers have not been reconstructed.

Three new regression tests failed before the fix and passed afterward; the full
engine/intake suite now passes 30 tests. Only live workflow 03 was patched and
republished, preserving its existing settings and credential bindings; n8n was
restarted. Its five embedded engine copies were updated. Other live workflows
were not reimported (their embedded helper copies do not call `applyExtraction`).
Public source exports were regenerated with the new engine throughout.

The native n8n memory smoke test uses installed extraction code with synthetic
model output, followed by real discovery/estimate subworkflows. Memory and
PHP 6,000–12,000 estimate checks passed without customer writes or Telegram sends.
This does not establish that Ollama will always classify correctly. A fresh
Telegram conversation remains the user acceptance check; local AI latency is
unchanged. A private workflow-03 rollback export was retained under `.runtime`.

Tool execution evidence, 2026-10-14. Initial live Telegram receipt/processing/delivery is verified. The complete estimate → consent → contact → handoff journey and screenshots remain pending. No production certification or overall completion is claimed.

| Milestone | Verified result | Remaining gate / teaching note |
|---|---|---|
| Business data | Existing live 001/002 preserved; migrations 003–006 applied; 25 services, 4 packages, 10 adjustments | 006 documents implementation defaults without changing approved weights or rates |
| Engine/intake | 27 tests PASS using live catalog; final revised engine imported, published and n8n restarted | Corrections, commercial/sensitive safeguards, intermediate and FAQ routing covered |
| Database | Rollback harness PASS including 003 twice; concurrent multi-session `p06_verify` PASS, all 22 table snapshots unchanged after cleanup | Synthetic delivery acknowledgements are not real network sends |
| Native workflows | Command, PHP 6,000–12,000 estimate and real local Ollama CRM discovery smoke PASS | Full live estimate/contact journey still needed |
| Runtime/export | 00–09 active, 10–12 manual; all 13 exports validate inactive/credential-free; private env ignored | Preserve learning workflow inactive and private staging private |
| Custom intake/tunnel | Node persisted at `/home/node/.n8n/custom/P06TelegramIntake.node.js`, reloaded; tunnel renewed privately; local/public invalid-auth checks 403 | Actual authenticated custom-intake DB-outage test remains unverified |
| ACK mechanism | Standard native Webhook + PostgreSQL probe: 200 after ~1.1s including 1s sleep; failure 500; probe unpublished | Mechanism check has narrower scope than the custom authenticated path |
| Live customer replies | Greeting and first Gmail–Sheets discovery completed first attempt; outbox sent with Telegram IDs | 6.6s / 67.5s observed latencies; user viewing the second reply is not confirmed |
| Owner/operations | Private owner setup message Telegram-confirmed; disposable-database admin create/update/approve/deactivate/audit and invalid-field tests PASS | Setup message created no lead and was not correlated with a real handoff ticket |
| Portfolio | Documentation/evidence matrix updated | Final live journey and screenshots pending; no Git push |

## Remaining work

1. Continue live acceptance on the final deployed engine. Migration 006's 24-field schema and scope/scoring notes describe implementation defaults; they do not grant new business approval or change approved prices/weights.
2. Complete the live estimate, consent, contact and ticket-correlated owner handoff journey. Verify each database record and Telegram result separately; do not infer that a user read a sent reply.
3. If testing database-outage behavior, test the actual authenticated custom intake path. Existing probe results establish only the standard `lastNode` HTTP/PostgreSQL mechanism.
4. Finish remaining matrix coverage and capture sanitized screenshots. Preserve webhook secrecy, owner-ID privacy and the inactive learning workflow. No Git push or public release.

Exactly-once Telegram delivery cannot be guaranteed after a crash or ambiguous acknowledgement. Inbox leases are 600 seconds; sender leases are 120 seconds.
