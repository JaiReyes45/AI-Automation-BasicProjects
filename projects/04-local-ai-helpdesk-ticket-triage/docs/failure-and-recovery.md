# Failure and recovery

Retryable failures are Ollama timeouts/5xx, temporary database errors, SMTP
errors, and interrupted executions. Retries are bounded to three attempts with
30-second, 2-minute, and 10-minute delays. Invalid intake is non-retryable.
Low confidence, ambiguity, safety concerns, and repeated invalid model output
are human-review outcomes.

After the last retry, the error workflow stores a sanitized `failed_jobs`
record and audit event. Reprocessing receives a failed-job ID, resumes only the
unfinished stage, and retains original ticket/outbox idempotency keys. It cannot
create a duplicate ticket or acknowledgement.

The deterministic fallback is category `unknown`, priority `P3`, queue
`manual_review`, confidence `0`, and human review required.
