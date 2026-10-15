# Client usage

Use a private Telegram chat and synthetic portfolio examples only. The assistant supports text discovery and preliminary fictional PHP pricing. It cannot promise project delivery, discounts, a final quote, or a human response time.

| Command | What to expect |
|---|---|
| `/start` | Introduction and command hints |
| `/services` | Active approved services |
| `/rates` | Informational package starting prices, never computed package totals |
| `/confirm` | Calculate an eligible service estimate after a pending requirements summary |
| `/human` | Record a local human-review ticket; owner notification is separate |
| `/privacy` | Explain storage, processors and privacy choices |
| `/consent` | Permit follow-up contact collection |
| `/contact demo@example.com` | Save synthetic contact after consent has been acknowledged |
| `/decline` | Decline/withdraw contact consent and clear current contact |
| `/reset` | Clear working requirements; retain history and existing consent |
| `/delete` | Request human-reviewed deletion; does not confirm erasure |

Example discovery message: “For a fictional business, copy email inquiries from Gmail to HubSpot, 20 per day. No AI, custom API, separate database, handoff system or reporting. Requested timeline 14 days; budget PHP 20,000. I am the decision-maker.” Answer any remaining discovery questions, inspect the summary and send `/confirm` only if it is accurate. Corrections should produce a revised summary. Expected narrow CRM base range is PHP 10,000–18,000, subject to the active approved catalog and scope checks.

The assistant asks one missing question at a time. It may route unclear, sensitive, complex or commercial requests to a person. Once handed off, ordinary discovery pauses; `/reset` alone does not resolve that review. Continue using privacy commands as needed.

Never send real customer records, passwords, keys, payment details, identity documents or someone else's contact details. This demo does not verify email ownership. Redaction is a protective layer, not a guarantee that every sensitive value is detected.

## Current live evidence and response time

Live `/start` and a simple Gmail–Sheets inquiry both completed on their first attempt; both outbox replies are `sent` with confirmed Telegram message IDs. Observed latency was 6.6 seconds for the greeting and 67.5 seconds for AI discovery. The user had reported seeing only the greeting; later database verification confirms the second reply was sent, not that the user saw it. These are observed timings, not response-time guarantees. Allow processing time before resending; the operator can check inbox/outbox status privately. The full live estimate, consent, contact and handoff journey remains pending.

For workflow requests, specify whether it is a simple workflow or multiple steps with validation/transformation. Two apps alone do not imply the simple rate. App changes invalidate confirmation; also state other scope changes (for example adding PostgreSQL), then review the revised summary and use standalone `/confirm`.
