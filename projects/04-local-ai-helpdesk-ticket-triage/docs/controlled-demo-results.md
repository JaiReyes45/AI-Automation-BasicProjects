# Controlled Demo Results

Executed on 2026-09-25 in a disposable local Compose environment. All requests
used synthetic `example.test` addresses. n8n and Mailpit remained bound to
localhost; no external mail or production data was used.

## Verified

- Normal intake completed through validation, Ollama classification,
  deterministic routing, durable persistence, notification outbox processing,
  and a Mailpit acknowledgement.
- Repeating the identical request with the same idempotency key left exactly
  one durable ticket and one notification-outbox item for that key.
- An account-takeover fixture followed the forced P1/security route, created a
  human-review task, and was resolved through the reviewer webhook into the
  `security_response` queue.

## Runtime fixes captured in this repository

- The least-privilege role now has `SELECT` as well as `INSERT` on
  `ticket_events`, because audit queries use `INSERT ... RETURNING`.
- The local n8n service allows only the Node.js `crypto` built-in needed by the
  intake Code node.
- The classifier supplies Ollama with a strict JSON schema, reducing invalid
  enum and type outputs before deterministic validation.
- The reviewer webhook uses the dedicated Respond to Webhook node already
  present on the canvas.

## Next test: notification failure and replay

This scenario remains intentionally unexecuted in the successful-demo pass.
Run it only in a disposable environment:

1. Record the current Mailpit inbox and outbox counts.
2. Stop Mailpit, submit one synthetic ticket, and allow three delivery
   attempts.
3. Confirm the existing outbox item becomes failed and a notification failed
   job is recorded.
4. Restore Mailpit and invoke the failed-job reprocessing webhook with that
   job ID.
5. Confirm the same outbox row is reset and delivered; no duplicate ticket or
   notification idempotency key may be created.

Mailpit stores messages in memory in this Compose configuration, so restarting
it clears its inbox. This is expected and is not evidence of message loss in
the notification outbox.
