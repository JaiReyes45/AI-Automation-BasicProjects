# Phase 3 — Intake, Validation, and Idempotency

## Status

Implemented and locally tested with synthetic leads on September 30, 2026.

## Purpose

Phase 3 creates a safe front door for lead data. It validates each request before
later automation can use AI, send messages, or update a CRM. It also makes retries
safe so a client cannot accidentally create the same submission twice.

## Implemented workflows

- `10-webhook-lead-adapter.json` accepts an HTTP request, extracts the request
  body, calls the orchestrator, and returns a controlled JSON response.
- `00-ai-lead-to-crm-orchestrator.json` provides one entry point for the complete
  pipeline and currently delegates intake work to Workflow 01.
- `01-intake-validation-persistence.json` normalizes and validates the payload,
  checks the submission ID, detects retries and conflicts, writes PostgreSQL
  records, and creates audit events.

Repository exports are deliberately inactive. Local sub-workflows were published
only as required for controlled webhook testing in this n8n version.

## Tested outcomes

| Test case | Expected outcome | Verified behavior |
|---|---|---|
| New valid submission | `CREATED`, HTTP 202 | One `AI_PENDING` record is created and may continue. |
| Valid UUID with invalid fields | `INVALID`, HTTP 422 | The invalid record and validation errors are stored; processing stops. |
| Malformed submission UUID | `INVALID_SUBMISSION_ID`, HTTP 422 | No lead-submission row is created; an audit event is recorded. |
| Exact retry | `IDEMPOTENT_REPEAT`, HTTP 200 | The original record is returned; downstream work does not repeat. |
| Same ID with changed payload | `SUBMISSION_ID_CONFLICT`, HTTP 409 | The original record is preserved and moved to `REVIEW_REQUIRED`. |

## Safety boundary

Only synthetic leads are used. The workflow exports contain credential references,
not credential values. Gmail, AI extraction, duplicate-person matching, scoring,
notifications, and HubSpot synchronization are not part of this completed phase.

## Reusable fixtures

The `fixtures/phase-3/` directory contains public-safe request bodies. The exact
retry fixture intentionally matches the valid fixture. The conflict fixture
intentionally reuses its submission ID while changing the message.
