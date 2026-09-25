# Repository operating instructions

## Secrets and source control

- Keep passwords, API keys, OAuth tokens, cookie values, and decrypted n8n credentials out of Git.
- Store local secrets only in `.env`, which is ignored. Keep `.env.example` limited to non-secret placeholders.
- Before committing an exported workflow, inspect its JSON for embedded credentials, tokens, personal data, webhook test data, and sensitive URLs. n8n credential references may be committed only when they contain identifiers or names and no secret material.
- Do not commit PostgreSQL data, n8n state, backups containing credentials, or Docker volume contents.

## Safe Docker Compose usage

- Run Compose commands from the repository root.
- Create local configuration with `cp .env.example .env`, then replace every placeholder in `.env` with a local value before starting services.
- Validate changes with `docker compose config` before starting or recreating services.
- Start the environment only when explicitly requested, using `docker compose up -d`.
- Inspect it with `docker compose ps` and `docker compose logs --tail=100 n8n`.
- Stop containers without deleting data by using `docker compose stop` or `docker compose down`.
- Never run `docker compose down -v`, `docker volume rm`, or any equivalent volume-deletion command without the user's explicit approval. The named volumes contain PostgreSQL data and n8n state.
- Do not expose n8n beyond the configured `127.0.0.1:5678` host binding unless the user explicitly requests and reviews that change.
- Do not start, stop, recreate, pull, or upgrade containers unless the task explicitly calls for it.

## n8n workflows

- Put reviewed workflow exports in the owning project's `workflows/` directory as JSON files.
- The repository `projects/` directory is mounted read-only at `/projects` in the n8n container for explicit import operations.
- Do not treat the mounted directory as an automatic backup of workflows stored in n8n's database.
- Prefer explicit import/export commands, and confirm the target file before overwriting an existing export.
- Preserve the `N8N_ENCRYPTION_KEY` used for an environment. Losing or changing it can make stored credentials unreadable.
