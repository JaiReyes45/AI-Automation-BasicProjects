# Project 05 — AI Lead-to-CRM Automation

## Status

In progress — planning and project foundation are complete; implementation and
public-safe workflow evidence are the next milestones.

## Business problem

Manual lead handling can be slow, inconsistent, and vulnerable to missed opportunities or duplicate records. This project simulates a reliable business system that captures, validates, analyzes, qualifies, stores, routes, and follows up with inbound leads.

## MVP goal

Build an n8n workflow that receives a synthetic lead through a webhook, validates and records it in PostgreSQL, extracts structured facts from its message using AI, deterministically scores the lead, then creates or updates appropriate records in HubSpot CRM.

## Core principles

- AI extracts and summarizes unstructured information; deterministic business rules control lead scoring and routing.
- PostgreSQL provides an operational audit trail; HubSpot is the sales-facing CRM.
- Every external integration must have clear error handling and traceable outcomes.
- Public portfolio materials use only synthetic lead data.
- Secrets, credentials, and private customer data are never committed.

## Planned stack

- n8n Community Edition
- PostgreSQL
- HubSpot CRM developer test account
- Ollama or a cloud LLM, selected after structured-output testing
- Docker Compose
- Git and GitHub

## Repository layout

- `docs/` — decisions, test plans, and technical documentation
- `database/` — SQL migrations and database documentation
- `diagrams/` — architecture and workflow diagrams
- `screenshots/` — public-safe evidence of completed milestones
- `workflows/` — exported n8n workflow JSON for this project
