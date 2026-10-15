# Lifecycle and Naming Contract

## Workflow names

Workflow exports use the required numeric prefixes:

`00` orchestrator, `01` Telegram intake, `02` persistence, `03` extraction,
`04` catalog search, `05` discovery, `06` estimates, `07` qualification,
`08` handoff, `09` response, `10` administration, `11` analytics, and `12`
failure/retry/replay.

## Core statuses

| Entity | Initial | Active/progress | Terminal or review |
|---|---|---|---|
| Conversation | `new` | `active`, `awaiting_customer`, `awaiting_consent` | `qualified`, `handed_off`, `closed`, `expired` |
| Message | `received` | `processing`, `sent` | `failed`, `ignored` |
| Lead | `unqualified` | `cold`, `warm`, `hot` | `handed_off`, `won`, `lost` |
| Handoff | `open` | `acknowledged`, `in_progress` | `resolved`, `cancelled` |
| Outbox job | `pending` | `processing`, `retry_wait` | `sent`, `dead_letter` |

## Idempotency

Telegram `update_id` and message ID are retained in `processed_updates` and
`messages`. Reprocessing an already accepted update must not create a second
message, estimate, lead, or handoff ticket.

## Audit events

Important decisions record an event type, actor (`system`, `ai`, or `human`),
correlation ID, input reference, output summary, and timestamp. Secrets and
raw credentials are never included in an event.
