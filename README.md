# AI Automation Basic Projects

An automation portfolio built around local-first AI workflows. The projects
show how n8n, Docker, PostgreSQL, Ollama, and deterministic business rules can
be combined into traceable, reviewable business automations.

## Start here

If you are reviewing this repository for engineering or automation work,
start with **Project 04 — Local AI Helpdesk Ticket Triage and SLA Router**. It
has architecture notes, database migrations, automated checks, a consolidated
workflow export, and documented controlled-demo results.

- [Open the featured helpdesk project](projects/04-local-ai-helpdesk-ticket-triage/README.md)
- [Read its controlled-demo results](projects/04-local-ai-helpdesk-ticket-triage/docs/controlled-demo-results.md)
- [See the portfolio case study](projects/04-local-ai-helpdesk-ticket-triage/docs/portfolio-case-study.md)

## Portfolio

| Project | Status | What it demonstrates | Review link |
| --- | --- | --- | --- |
| 01 — Local AI Chatbot | Learning prototype | Local LLM orchestration with n8n and Ollama | [Project README](projects/01-local-ai-chatbot/README.md) |
| 02 — Local AI Expense Tracker | Built local workflow | Validation, AI classification, confidence guardrails, and PostgreSQL persistence | [Project README](projects/02-local-ai-expense-tracker/README.md) |
| 03 — Local AI LTO OR/CR Automation | Prototype | Vision extraction, duplicate detection, validation, and manual-review routing | [Project README](projects/03-local-ai-lto-automation/README.md) |
| 04 — Helpdesk Ticket Triage and SLA Router | Featured; controlled demo verified | Idempotency, AI safety guardrails, routing, outbox delivery, human review, and SLA operations | [Project README](projects/04-local-ai-helpdesk-ticket-triage/README.md) |
| 05 — AI Lead-to-CRM Automation | In progress | Requirements, data contract, scoring model, and implementation plan for a CRM workflow | [Project README](projects/05-ai-lead-crm-automation/README.md) |

## What this portfolio emphasizes

- **AI with guardrails:** models extract or recommend; deterministic rules own validation, safety, and routing.
- **Operational reliability:** durable data, idempotency, audit trails, retries, and human-review paths are designed in rather than added later.
- **Local, reproducible demos:** the shared Docker Compose stack runs n8n, PostgreSQL, Ollama, and Mailpit locally.
- **Honest evidence:** each project is labelled by its current maturity. Only completed, synthetic demo results are presented as verified.

## Repository layout

```text
projects/     Individual project documentation, code, fixtures, migrations, and workflow exports
backups/      Local-only operational backups (ignored by Git)
compose.yaml  Shared local development stack
```

Every project keeps its workflow export alongside its documentation so it
remains self-contained. The shared Compose stack mounts `projects/` read-only
inside n8n at `/projects` for explicit import operations.

## Run locally

From the repository root, create a local configuration from the example and
start the stack:

```bash
cp .env.example .env
docker compose config --quiet
docker compose up -d
```

Read the relevant project README before importing or activating any workflow.
Use only fresh local credentials in `.env`; never commit secrets, production
data, or n8n credential exports.

## Review and contribution standards

- Keep all public examples and screenshots synthetic and safe to share.
- Document the current status, setup, inputs/outputs, and validation evidence for each project.
- Export workflows without credentials or embedded secrets.
- Run applicable checks before proposing changes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the project checklist and
[SECURITY.md](SECURITY.md) for responsible disclosure guidance. See
[Workflow Tools setup](docs/workflow-tools.md) for local linting, testing,
mocking, and workflow-rendering commands.

## License

No license has been selected yet. Permission to reuse this work is not granted
until the repository owner chooses and adds one.
