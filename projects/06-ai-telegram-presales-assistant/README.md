# Project 06 — AI Telegram Pre-Sales Assistant

ChatterBox is a local-first pre-sales assistant for freelance automation services,
built with Telegram, n8n, PostgreSQL, and Ollama.

## Status

**Implemented locally; acceptance testing in progress.** Last reviewed: 2026-10-15.

42 engine/intake tests pass. Synthetic multi-turn restaurant, transport, and
healthcare-administration checks have run through installed n8n workflows.
Initial live Telegram receipt and replies are verified. The complete live
estimate → consent → contact → ticket-correlated owner handoff and final
screenshots remain pending. This is a portfolio demo, not a production service.

Public-source workflow exports are inactive, have no credential references or
execution data, and require local configuration before activation. The repository
contains no customer database, bot token, owner chat ID, or live tunnel address.

## Business problem

Freelancers repeatedly answer service and pricing questions, clarify manual
processes, and collect requirements before a useful sales conversation can begin.
This assistant gathers that context, uses an approved catalog for preliminary
estimates, and prepares a traceable human-review handoff.

## Implemented behavior

- Accept private Telegram text with durable ingestion and duplicate detection.
- Extract structured facts locally; validate model output before use.
- Preserve requirements across turns and handle clear pending-question answers.
- Distinguish an unanswered software question from an explicit manual/no-app setup.
- Ask process-based follow-ups across industries; route sensitive or unsupported
  scope to human review rather than promising industry-specific compliance.
- Calculate preliminary service ranges and lead scores using deterministic rules.
- Require consent before collecting follow-up contact details.
- Persist decisions, audit records, inbox/outbox jobs, retries, and review tickets.

All catalog prices are **fictional PHP portfolio examples**. Package starting
prices are informational; automatic estimates use approved service ranges.

## Core principles

- AI extracts facts; it does not set prices, discounts, or final commitments.
- PostgreSQL is the source of truth for business data and conversation state.
- Incoming messages are durable before slow AI processing begins.
- Unknown delivery outcomes require review; exactly-once Telegram delivery is
  not guaranteed after an ambiguous network failure.
- Secrets and real customer records stay out of source control.

## Implemented stack

- n8n 2.34.5 with a custom authenticated Telegram intake node
- PostgreSQL 16 for catalog, state, audit, and durable work queues
- Local Ollama with `qwen2.5:3b`
- Telegram Bot API and a temporary Cloudflare HTTPS tunnel for local demos
- Isolated Docker Compose stack; Mailpit is available for local development

## Repository layout

| Directory | Contents |
|---|---|
| `docs/` | Setup, architecture, policies, verification, and demo guide |
| `database/` | Six numbered migrations, contract, and database tests |
| `diagrams/` | Architecture diagram |
| `runtime/` and `nodes/` | Decision engine and custom intake node |
| `tests/` and `scripts/` | Regression tests, builders, checks, and operator tools |
| `workflows/` | Thirteen inactive, credential-free n8n exports |
| `screenshots/` | Reserved for reviewed synthetic evidence; none included yet |

## Workflow map

| Workflow | Responsibility |
|---|---|
| 00 | Claim durable inbox work, coordinate 03–08, commit decisions |
| 01–02 | Authenticate/normalize Telegram updates and persist atomically |
| 03 | Preflight, clear-answer handling, validated local AI extraction |
| 04–05 | Approved catalog matching and one-question-at-a-time discovery |
| 06–08 | Deterministic estimates, qualification, and human-review decisions |
| 09 | Ordered Telegram outbox delivery and outcome recording |
| 10–12 | Manual catalog, analytics, and failed-work inspection |

See the [architecture and lifecycle](docs/architecture-lifecycle.md) for the
separate ingestion, decision, and delivery paths.

## Start here

1. Read the [setup guide](docs/setup.md) before starting or importing anything.
2. Review the [catalog and pricing rules](docs/catalog-pricing.md).
3. Run the [verification checks](docs/test-matrix.md), then follow the
   [demo checklist](docs/demo-checklist.md) using synthetic data only.

For recorded results and limitations, see the
[latest verification record](docs/verification-record-2026-10-15.md) and
[status roadmap](docs/status-roadmap.md).

## Known limitations

- Local AI generation may take about a minute; short deterministic answers are
  faster, but broad language understanding is not guaranteed.
- FAQ lookup is normalized exact matching, not semantic retrieval.
- A Quick Tunnel requires a running local process and changes address on restart.
- Healthcare administration examples do not certify handling of patient data.
- Full live estimate-to-handoff acceptance and authenticated custom-intake
  database-outage testing remain unfinished.
- Test helpers assume the documented Compose project/container and database names.

Do not treat this demo as production-ready or use it for real sensitive records.
