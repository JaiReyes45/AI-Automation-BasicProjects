# Local setup and verification

This project has its own Compose stack, separate from the repository's shared
stack. Run the following commands from the repository root in Ubuntu/WSL with
Docker Compose, Python 3, and Git available. These instructions do not start or
modify any environment automatically.

## 1. Configure the isolated stack

Copy the project's `.env.example` to `.env` **only for a new installation**:

```bash
cp projects/06-ai-telegram-presales-assistant/.env.example projects/06-ai-telegram-presales-assistant/.env
```

Edit `.env` locally: replace the database-password and encryption-key placeholders.
Never replace an existing n8n encryption key or overwrite a configured `.env`.
Keep the documented database/user/project names unless you also adapt the helper
scripts. Bindings are localhost-only: n8n 5686, PostgreSQL 5436, Ollama 11436,
and Mailpit 8026. Check for port conflicts first.

```bash
docker compose --project-directory projects/06-ai-telegram-presales-assistant config --quiet
docker compose --project-directory projects/06-ai-telegram-presales-assistant up -d
docker compose --project-directory projects/06-ai-telegram-presales-assistant exec ollama ollama pull qwen2.5:3b
```

The local model uses your hardware. No hosted AI subscription is configured.
Do not delete the named volumes; they contain the database and encrypted n8n state.

## 2. Initialize the database

For a fresh demo database, apply the numbered migrations once:

```bash
python3 projects/06-ai-telegram-presales-assistant/scripts/migrate.py
```

The runner uses `presales.schema_migrations` to skip completed versions. Inspect
the ledger and take a private backup before updating an existing database. Never
rerun migration 002 manually: its FAQ inserts can duplicate rows.

## 3. Configure n8n and Telegram privately

Open `http://localhost:5686`, finish owner-account setup, and create the project
PostgreSQL and Telegram credentials in n8n. PostgreSQL uses `postgres:5432` inside
Docker, not the host port. Create a dedicated demo bot using BotFather; store
its token only in n8n credentials.

Review [Telegram setup](telegram-setup.md). The installer copies the custom intake
node to the persisted n8n volume and binds existing encrypted credential references
privately. It expects exactly one Telegram and one PostgreSQL credential and an
existing n8n owner project; if that does not match your environment, bind manually.

```bash
python3 projects/06-ai-telegram-presales-assistant/scripts/build_workflows.py
python3 projects/06-ai-telegram-presales-assistant/scripts/install_workflows.py
docker compose --project-directory projects/06-ai-telegram-presales-assistant restart n8n
```

The installer can overwrite workflows with the same `p06Workflow00`–`12` IDs.
Back up existing workflows privately before importing updates. Default installation
does not publish the workflows. Confirm the custom node loads and each subworkflow
reference and credential is correct before publication.

For a controlled Telegram demo, run a tunnel to port 5686, put the generated HTTPS
base URL with trailing slash in local `WEBHOOK_URL`, and recreate n8n to load the
updated environment. Keep the editor authenticated; never tunnel the database or
Ollama. Publish internal 02–08, then ingress/worker workflows 01/00/09. CLI
publication requires an n8n restart. Keep 10–12 manual. This pinned n8n 2.34.5
configuration uses `WEBHOOK_URL`; review configuration before any version upgrade.

Owner notifications need a separately verified private destination. Do not use
`configure_owner.py` in a multi-user environment: it is a one-time helper that
assumes the sole customer is the operator's own test account. A setup-message
delivery is not proof of a ticket-correlated handoff.

## 4. Run safe checks

With the documented stack and seeded catalog running:

```bash
python3 projects/06-ai-telegram-presales-assistant/scripts/verify_runtime.py
python3 projects/06-ai-telegram-presales-assistant/scripts/verify_public_exports.py
bash projects/06-ai-telegram-presales-assistant/database/tests/run_rollback_tests.sh
```

The first command copies test source/catalog into temporary container files, not
customer records. The database harness runs in an isolated transaction that rolls
back. Native smoke checks require installed subworkflows, create/update a dedicated
synthetic test workflow, and may call Ollama; they do not send Telegram messages.

Do not run admin, replay, owner-send, publication, or outage probes merely to inspect
the project. Those commands have operational side effects. Follow the
[test matrix](test-matrix.md) and use disposable databases for mutation tests.
