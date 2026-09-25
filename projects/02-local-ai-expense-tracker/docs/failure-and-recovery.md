# Failure and recovery

## Current behavior

The exported workflow contains validation and confidence branches, but it does
not document durable retries, idempotency keys, an outbox, dead-letter records,
or replay controls. A repeated webhook request may therefore need separate
duplicate-handling design before this is used for real financial records.

## Operational risks to test

- Ollama unavailable or slow
- PostgreSQL unavailable during persistence
- Malformed model output
- A request repeated after a client timeout
- A low-confidence expense left without reviewer follow-up

## Recommended next controls

Add explicit error branches, a unique client request ID, bounded retries, and a
manual-review queue with a recorded resolution. Do not claim these controls are
present until they are implemented and tested.
