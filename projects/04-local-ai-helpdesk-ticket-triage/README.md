# Local AI Helpdesk Ticket Triage and SLA Router

A local-first, portfolio-quality helpdesk triage automation using n8n,
PostgreSQL, Ollama, and Mailpit.

> **Status:** Featured project — controlled demo verified
>
> **Quick review:** Start with the [architecture](docs/architecture.md), then
> the [controlled-demo results](docs/controlled-demo-results.md) for recorded
> normal intake, idempotency, and security-review evidence.

## Guarantees

- AI recommends; deterministic code owns safety, routing, and SLA.
- A ticket is durable before classification or notification.
- Correlation IDs and unique idempotency keys prevent duplicate tickets.
- Model output is untrusted until strict schema validation succeeds.
- Low-confidence, risky, and failed classifications enter human review.

## Components

- n8n 2.34.5: orchestration; all development workflows stay inactive.
- PostgreSQL 16: tickets, audit events, classification runs, outbox, and DLQ.
- Ollama: internal-only local inference at `http://ollama:11434`.
- Mailpit: internal SMTP capture; inbox UI at `http://127.0.0.1:8025`.

## Contents

- [Architecture](docs/architecture.md)
- [Happy path](docs/happy-path.md)
- [Edge cases](docs/edge-cases.md)
- [Failure and recovery](docs/failure-and-recovery.md)
- [Security](docs/security.md)
- [Testing](docs/testing.md)
- [Evaluation report](docs/evaluation-report.md)
- [Controlled demo runbook](docs/controlled-demo.md)
- [Controlled demo results](docs/controlled-demo-results.md)
- [Unified workflow operation guide](docs/unified-workflow-operation.md)
- [Portfolio case study](docs/portfolio-case-study.md)
- [Migration](migrations/001_helpdesk.sql)
- [Synthetic fixtures](fixtures/tickets.json)

The initial business calendar is Monday-Friday, 09:00-17:00 Asia/Manila, with
P1 operating 24x7. Public holidays are a documented production enhancement.
