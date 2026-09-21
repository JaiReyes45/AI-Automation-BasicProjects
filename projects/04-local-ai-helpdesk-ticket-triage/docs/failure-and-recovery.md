# Failure and recovery

Retryable failures are Ollama timeouts/5xx, temporary database errors, SMTP
errors, and interrupted executions. Retries are bounded to three attempts with
30-second, 2-minute, and 10-minute delays. Invalid intake is non-retryable.
Low confidence, ambiguity, safety concerns, and repeated invalid model output
are human-review outcomes.

After the last retry, workflow 06 stores a sanitized `failed_jobs` record and
an audit event. It records only the stage, safe error code, source identifiers,
ticket reference, and idempotency key—never raw ticket text, SMTP details, or
credential material. Classification failures are captured directly from workflow
02; workflow 04 captures an SMTP failure after its third delivery attempt.

Workflow 07 accepts a failed-job ID and atomically claims an unresolved,
replayable job. Classification/routing replay reloads the original durable
ticket by its idempotency key and reruns workflows 02 and 03. Notification replay
only resets the same failed outbox row for a later worker attempt. A failed job
can be claimed at most three times; concurrent or already-resolved claims return
no job. These operations retain the original ticket/outbox idempotency keys and
cannot create a duplicate ticket or outbox item.

The deterministic fallback is category `unknown`, priority `P3`, queue
`manual_review`, confidence `0`, and human review required.
