# Testing

Run deterministic tests:

```bash
node projects/04-local-ai-helpdesk-ticket-triage/tests/run-tests.js
node projects/04-local-ai-helpdesk-ticket-triage/tests/workflow-contracts.js
```

Run the database constraints test through `psql` in a transaction; it rolls
back all synthetic rows. Keep n8n workflows inactive while running these tests.

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

## 2026-09-21 baseline results

- 22 deterministic validation, routing, retry, and SLA cases passed.
- 23 static workflow-contract cases passed, including inactive-state, secret-like
  field, capture/replay, and SLA-monitor checks.
- The rollback-only PostgreSQL constraint test passed, including duplicate
  protection, dead-letter claim-after-resolution rejection, and SLA-breach
  idempotency.
- One live internal Ollama injection-style synthetic ticket returned parseable
  JSON with every required contract field and a valid confidence value.

Workflows remained inactive throughout. Outage, worker-retry, and full
workflow-reprocessing exercises require a controlled execution harness and are
not represented by the baseline results.

## Demo script

1. Show the architecture and local-only stack.
2. Submit a synthetic technical ticket and show the correlation ID.
3. Show the ticket, classification run, audit records, route, and SLA in PostgreSQL.
4. Show the captured Mailpit acknowledgement.
5. Repeat the request to demonstrate idempotency.
6. Submit account takeover fixture to demonstrate forced security review.
7. Show a failed job and idempotent replay.
