# Phase 6 — Durable Outbox, Retries, Dead Letters, and Replay

## Why an outbox exists

Calling Gmail, HubSpot, or another service directly inside the main lead
workflow can lose work when the service is temporarily unavailable. The outbox
stores the intended action in PostgreSQL first. A separate worker performs it.

## Job lifecycle

`PENDING → PROCESSING → SENT`

Temporary failures use `PROCESSING → RETRY → PROCESSING`. The delay grows after
each attempt. When `max_attempts` is reached, the job becomes `DEAD_LETTER` and
waits for a person to inspect it.

## Workflow 04

`04 - Notification Outbox Worker`:

1. claims only one due job with `FOR UPDATE SKIP LOCKED`;
2. increments its attempt count;
3. performs the delivery adapter;
4. marks success as `SENT`; or
5. schedules a retry/dead letter and records an audit event.

The repository version uses a synthetic delivery adapter so tests cannot send
real messages. Replace it with Gmail only after creating the credential in n8n.

## Workflow 05

`05 - Dead Letter Replay` accepts one reviewed job ID. It resets only a
`DEAD_LETTER` job to `PENDING`, clears its error and lock, resets the attempt
count, and records an `OUTBOX_JOB_REPLAYED` audit event.

## Verified result

- A normal CRM job was claimed and marked `SENT`.
- A synthetic forced failure with `max_attempts = 1` became `DEAD_LETTER`.
- Workflow 05 returned that job to `PENDING` with attempt count `0` and audit
  event `28`.
