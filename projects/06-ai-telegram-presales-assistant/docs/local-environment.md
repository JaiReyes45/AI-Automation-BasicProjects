# Phase 2 — Isolated Local Environment

## Purpose

Project 06 uses its own Docker Compose project and named volumes. This keeps
its n8n state, PostgreSQL data, and Ollama model storage separate from Project
05 while allowing both projects to run on the same machine.

## Reserved host ports

| Service | Host port | Container port | Local use |
|---|---:|---:|---|
| n8n | 5686 | 5678 | `http://localhost:5686` |
| PostgreSQL | 5436 | 5432 | local database tools |
| Ollama | 11436 | 11434 | local model API |
| Mailpit | 8026 | 8025 | `http://localhost:8026` |

Container-to-container connections use service names, not host ports. For
example, n8n reaches PostgreSQL at `postgres:5432` and reaches Ollama at
`ollama:11434`.

## Secret handling

`.env.example` contains placeholders only. Create `.env` locally and set:

- `POSTGRES_PASSWORD` — a local database password
- `N8N_ENCRYPTION_KEY` — a long random value that must remain stable for this
  environment; changing it can make stored n8n credentials unreadable

Do not commit `.env`, credentials, database dumps, n8n state, or model data.

## Verification sequence

After local configuration is complete:

1. Run `docker compose config` from this project directory.
2. Start with `docker compose up -d`.
3. Check with `docker compose ps`.
4. Open n8n at `http://localhost:5686`.
5. Open Mailpit at `http://localhost:8026`.
6. Confirm Ollama health before downloading `qwen2.5:3b`.

Do not use `docker compose down -v`; named volumes contain project state.
