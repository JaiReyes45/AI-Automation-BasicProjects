# Testing

Run deterministic tests:

```bash
node projects/04-local-ai-helpdesk-ticket-triage/tests/run-tests.js
```

Validate Compose before starting or recreating services:

```bash
docker compose config
docker compose ps
```

The test plan covers validation, database constraints, schema output, routing,
SLA, idempotency, retry, prompt injection, Ollama/PostgreSQL/Mailpit outages,
and dead-letter replay. The evaluation report must record total cases,
classification agreement, invalid-output rate, review rate, duplicate result,
average duration, recovery result, and known limitations. Do not claim metrics
until the test execution records them.

## Demo script

1. Show the architecture and local-only stack.
2. Submit a synthetic technical ticket and show the correlation ID.
3. Show the ticket, classification run, audit records, route, and SLA in PostgreSQL.
4. Show the captured Mailpit acknowledgement.
5. Repeat the request to demonstrate idempotency.
6. Submit account takeover fixture to demonstrate forced security review.
7. Show a failed job and idempotent replay.
