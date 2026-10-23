# D2.1 email and event contract

This is a controlled English-language parser, not a universal email interpreter.
Only synthetic mailboxes ending in `.test` or `.invalid` are accepted by the
running HTTP adapter. Real Gmail integration is deliberately not enabled.

## Email envelope

Required strings: `account`, `id`, `received_at` (ISO 8601 with timezone), `body`.
Optional strings: `thread_id`, `sender`, `subject`.
`account` + `id` is the durable duplicate key. Thread IDs alone are not application IDs.

The parser strips common quoted replies, script/style tags, and HTML markup.
It reads explicit `Company:`, `Role:`, and `Reference:` lines. Other layouts
remain unknown and need review; real Indeed/JobStreet templates are not verified.
The original title is preserved and recognized internship titles normalize to
IT Intern, QA Engineer Intern, or Software Engineer Intern. Deadlines remain null.

## Classification output

`stage`, `evidence`, `reason`, `normalized_role`, `original_role`, `company`,
`reference`, and `deadline`. Stage values currently detected: submitted,
reviewing, information, assessment, interview, offer, rejected. Offers are never
automatically interpreted as accepted or hired.

Conflicting or uncertain statements route to review. Vacancy recommendations
are opportunities, not submitted applications. Absence of a response is not rejection.

## Application matching

Match only within the same account. Prefer explicit reference, then an established
thread. Conflicting reference/thread/company/role evidence requires review.
Company alone is never enough. A new submitted application requires company,
recognized role, and reference. Out-of-order events, regressions, and updates to
closed applications require review rather than silently overwriting progress.

The database transaction stores one message outcome, an event when matched,
the current application, and a label job. Unmatched/conflicting outcomes remain
reviewable in the messages table. A review UI and durable manual corrections are later work.

## Local API (internal Docker network only)

All POST routes require `Authorization: Bearer <local service token>`.
The token is stored in `.env` and n8n's credential manager, never in workflow JSON.

| Route | Input | Result |
|---|---|---|
| POST /ingest | Email envelope | Classification, action, application_id, duplicate |
| POST /deliver | `{}` or synthetic test `{"inject_failure":true}` | Delivery counts and queue status |
| POST /status | `{}` | Application/event/message counts, review count, queue states |
| GET /health | None | Service health, synthetic mode |

Malformed input returns 400; bad credentials return 401; storage failure returns
503 so the same message can be retried. Requests are capped at 100 KB.

## Label-delivery boundary

Today's provider is a local `mock_labels` table. No Gmail call occurs. Each job
targets a message; confidently related messages receive the application's latest
stage. Only `Career/Stage/` and `Career/Role/` labels are replaced. Other labels,
including INBOX, are preserved. Unknown messages receive Needs Review.

`delivery_attempts` records failures, and jobs become failed or delivered. Three
failed attempts place a job in dead status. Workflow 02 reports failed/dead jobs
as errors. Retry a transient failure by running delivery again. Dead jobs require
operator diagnosis; no automatic infinite retry or destructive reset is provided.

For D3.2, replace the mock provider with Gmail label-name-to-ID resolution and
messages.modify; acknowledge jobs only after success. Add Google OAuth, sender
validation, production retry/backoff, rate limits, and reconciliation. The current
SQLite test store must be migrated to PostgreSQL before connecting the real UI.
Do not claim mock delivery guarantees exactly-once Gmail delivery.
