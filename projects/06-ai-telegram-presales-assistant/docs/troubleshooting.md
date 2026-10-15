# Troubleshooting

Inspect the smallest relevant record using redacted IDs and status fields. Do not paste tokens, private owner IDs, raw model output or full payloads into tickets or screenshots.

| Symptom | Check and next action |
|---|---|
| Telegram receives no reply | Check current HTTPS hostname, webhook registration, ingress 01 and workers 00/09; distinguish no inbox receipt from pending decision or pending delivery |
| Custom intake type is missing | Persisted `/home/node/.n8n/custom/P06TelegramIntake.node.js` and reload are verified; after updates inspect node loading and bindings before republishing |
| CLI publish succeeded but no events arrive | Restart n8n after CLI publication, then verify node loading, schedules and webhook registration privately; script output alone is not active-state evidence |
| Webhook returns success but no durable receipt exists | Standard `lastNode` + PostgreSQL probe returned delayed 200 and failure 500; actual authenticated custom-intake DB-outage coverage is still missing. Inspect the specific path before claiming durable ACK under outage |
| Unexpected webhook requests | Check custom-trigger authentication/rejection using sanitized diagnostics; protect URL/path and authentication secret; encrypted bot credentials alone do not validate callers |
| Worked in test but stopped after activation | A bot has one webhook; verify the intended test/production registration and current tunnel hostname |
| `/services` works but discovery is slow | Commands bypass the model. Initial live greeting took 6.6s and AI discovery 67.5s; inspect processing/outbox before resending. These observations are not an SLA |
| SQLSTATE `55000` | Inspect claim token and expiration; a stale worker must not commit or acknowledge delivery |
| Slow extraction repeatedly loses its claim | Inbox lease is 600 seconds; sender lease is 120 seconds. Check actual processing duration and failure handling; broad outage recovery still needs testing |
| Contact was stored but no lead/handoff appears | Verify acknowledged consent, redacted contact marker and `contact_present` in claimed state; do not expose the stored email to debug |
| No automatic estimate | Confirm pending summary and `/confirm`, approved service route, valid one-time range, review flags, timeline and PHP 85,000 upper-bound ceiling |
| Package starting price differs from estimate | Expected: packages are informational; estimates use service ranges from 005 |
| CRM or chatbot scope seems too broadly accepted | Check actual provider/integration suitability; category/app count alone is insufficient evidence of narrow supported scope |
| Model tries to invent price or reveal instructions | Reject untrusted fields/instructions; respond with approved text only; never forward raw generation |
| Handoff recorded but owner sees nothing | Check private destination configuration and separate owner outbox status; a local ticket is not delivery confirmation |
| Later messages remain queued | Earlier dead-letter work blocks ordered processing/delivery; inspect and resolve the earlier record first |
| Telegram 429 | Inspect confirmed rate-limit result and retry delay; verify actual adapter behavior with a controlled test |
| Telegram 400/401/403 | Inspect sanitized failure, credential configuration and bot access privately; do not repeatedly replay a permanent failure |
| Timeout/crash during send | Delivery may have happened. Quarantine as uncertain and inspect before explicit replay; exactly-once Telegram delivery cannot be guaranteed |
| `/reset` still says awaiting human | Reset does not resolve the handoff; operator must review and resolve remaining tickets |
| Duplicate FAQ entries | Check whether original 002 was rerun; preserve edited answers and review duplicates manually; do not rerun seeds |
| Missing 004 catalog changes after runner | Runner scans `database`, while 004 is in `catalog`; complete ordered packaging/application before 005 |
| Existing learning workflow changed | Stop rollout and inspect the import target; preserve the learning workflow inactive |

Failure reports should include scenario, time, workflow number, redacted correlation reference, expected/actual status and source revision. Omit webhook paths, authentication values and complete registration responses. Tool results confirm renewed tunnel, reloaded custom node, 00–09 active and 10–12 manual. Live `/start` and a simple Gmail–Sheets inquiry both completed on their first attempt; both outbox replies are `sent` with confirmed Telegram message IDs. Observed latency was 6.6 seconds for the greeting and 67.5 seconds for AI discovery. The user had reported seeing only the greeting; later database verification confirms the second reply was sent, not that the user saw it.

The owner setup message confirms destination reachability only; it is not a real ticket-correlated handoff. Full live estimate/consent/contact/handoff and screenshots remain pending. Final engine deployment and migration 006 completion require separate confirmation.
