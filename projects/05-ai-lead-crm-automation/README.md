# Project 05 — AI Lead-to-CRM Automation

## Status

Portfolio-ready, end-to-end implementation. The system has been tested locally
with synthetic data and a Gmail-to-HubSpot flow. It includes the isolated Docker
environment, PostgreSQL CRM schema, webhook and Gmail intake, validation,
idempotency, local AI extraction, deterministic scoring, human-review routing,
HubSpot contact/company/deal synchronization, retry handling, dead-letter
handling, and manual replay.

The verified Gmail path accepts ordinary natural-language inquiries carrying the
`CRM-LEAD` label. Successful messages are marked read and moved to
`CRM-PROCESSED`; incomplete or failed messages remain unread and move to
`CRM-REVIEW`. A completed synthetic run produced a HOT lead, created and
associated the HubSpot records, and ended with PostgreSQL status `CRM_SYNCED`.

For public safety, repository exports are inactive and contain no credential
references, OAuth tokens, account metadata, or live trigger state. After import,
configure the documented PostgreSQL, Gmail OAuth, HubSpot private-app, and local
Ollama connections before activating the workflows.

## Business problem

Manual lead handling can be slow, inconsistent, and vulnerable to missed opportunities or duplicate records. This project simulates a reliable business system that captures, validates, analyzes, qualifies, stores, routes, and follows up with inbound leads.

## MVP goal

Build an n8n system that receives leads through a website webhook or labeled
Gmail message, validates and records each submission in PostgreSQL, extracts
structured facts from natural language using AI, deterministically scores the
lead, and creates or updates the appropriate HubSpot CRM records.

## Core principles

- AI extracts and summarizes unstructured information; deterministic business rules control lead scoring and routing.
- PostgreSQL provides an operational audit trail; HubSpot is the sales-facing CRM.
- Every external integration must have clear error handling and traceable outcomes.
- Public portfolio materials use only synthetic lead data.
- Secrets, credentials, and private customer data are never committed.

## Implemented stack

- n8n Community Edition
- PostgreSQL
- HubSpot CRM private app and test account
- Gmail OAuth with label-based intake and finalization
- Ollama using `qwen2.5:3b` for local structured extraction
- Docker Compose
- Git and GitHub

## Repository layout

- `docs/` — decisions, test plans, and technical documentation
- `database/` — SQL migrations and database documentation
- `diagrams/` — architecture and workflow diagrams
- `screenshots/` — public-safe evidence of completed milestones
- `workflows/` — exported n8n workflow JSON for this project

## Workflow map

| Workflow | Responsibility | Verification |
|---|---|---|
| `00` | Coordinates intake, AI extraction, scoring, and CRM sync | End-to-end tested |
| `01` | Normalizes, validates, deduplicates, and persists intake | Tested |
| `02` | Calls local Ollama, validates strict JSON, repairs once, and routes failures to review | Success, repair, and failure paths tested |
| `03` | Calculates the deterministic score, qualification, relationship type, and route | Tested |
| `04` | Claims due outbox jobs and applies sent, retry, or dead-letter transitions | Success and dead-letter paths tested |
| `05` | Replays one selected dead-letter job | Tested |
| `10` | Accepts website webhook requests and returns safe HTTP responses | Tested |
| `11` | Extracts natural-language Gmail leads and applies processed/review labels | End-to-end synthetic path tested; live credentials required after import |
| `20` | Upserts and associates HubSpot contacts, companies, and HOT-lead deals | Contact/company/deal path tested |

## Start here

For a guided demonstration, follow `docs/video-demo-guide.md`. For the precise
test evidence and limitations, read `docs/test-matrix.md`.
