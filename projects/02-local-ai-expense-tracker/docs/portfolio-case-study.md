# Portfolio case study: Local AI Expense Tracker

## Problem

Expense descriptions are unstructured, but downstream reporting benefits from
consistent categories and stored records.

## Solution

Built a local n8n workflow that validates an expense payload, uses local AI for
classification, routes uncertain classifications to review, and persists a
normalized result in PostgreSQL.

## What it demonstrates

- Webhook-based automation and a Python test client
- Structured local LLM output
- Confidence-based automation guardrails
- PostgreSQL persistence

## Honest scope

The workflow is built but lacks recorded controlled-demo results and the
reliability controls required for a real financial system, such as idempotency,
auditable review resolution, and durable failure recovery.

## Next milestone

Run a documented synthetic test suite, then implement duplicate prevention and
a durable review/recovery path.
