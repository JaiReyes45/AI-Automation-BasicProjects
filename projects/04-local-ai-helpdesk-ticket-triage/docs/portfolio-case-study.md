# Portfolio case study

## Problem and users

Small support teams need consistent ticket triage without sending sensitive
ticket content to a third-party AI provider. This project targets internal
support operators and reviewers.

## Decisions

n8n coordinates small workflows; PostgreSQL is the system of record. Ollama
recommends a structured classification, while deterministic JavaScript rules
own safety, routing, priority, and SLA. Mailpit proves notification behavior
without external email delivery.

## Reliability and limitations

Idempotency and an outbox prevent duplicate tickets and mail. Human review
catches uncertainty and risk. Retries are bounded and terminal errors are
retained. Production would add authenticated intake, TLS, holiday calendars,
alerts, managed secrets, backup/recovery drills, role separation, and a real
mail provider.
