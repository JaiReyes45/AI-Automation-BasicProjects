# Project 07 local Docker setup

Run these commands from the AI-Automation-BasicProjects repository root in WSL.
The Compose project is `project07-automated-career-opportunity-manager`.

## Configure and start

```bash
python3 projects/07-automated-career-opportunity-manager/scripts/setup_local.py
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation config --quiet
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation up -d --build
```

Local settings are generated only if absent. Existing encryption keys are preserved;
invalid existing settings cause an error. Do not commit .env or share its values.
Compose now requires all three settings even for web-only validation.

- Flutter web preview: http://localhost:8087
- n8n editor: http://localhost:5678
- PostgreSQL: internal network only, stores n8n state.
- Engine: internal port 8765 only, synthetic email API and SQLite test store.

The n8n port is 5678, replacing the earlier unactivated 5687 proposal. Do not run
another stack binding 5678 simultaneously. Keep the existing portfolio stack stopped
or arrange a reviewed port change. Only this project's services are managed here.

## First installation

Create your local n8n owner account in its UI. Then import the credential and four
inactive workflows:

```bash
python3 projects/07-automated-career-opportunity-manager/scripts/import_n8n.py
python3 projects/07-automated-career-opportunity-manager/scripts/verify_n8n.py
```

The importer uses a temporary private credential file inside n8n, imports it into
n8n's encrypted credential store, and removes the temporary file. No secret goes
into the exported JSON. Reimporting uses the same Project 07 workflow IDs and
replaces those workflows; export any intentional UI edits first.

In n8n, open workflow 03 and select Execute workflow. It verifies a submission,
duplicate delivery, interview update, simulated mailbox outage, and recovery.
Workflow 04 intentionally ends in an error; it demonstrates the validation path.
No workflow is published or scheduled. No Gmail account is connected.

## Rebuild the web app after changing Dart

The nginx image consumes a host-built Flutter release. From the project folder,
with Flutter 3.47.7 installed:

```bash
flutter pub get
flutter build web --no-web-resources-cdn
```

Return to the repository root and rerun Compose up with `--build web` and the same
explicit env-file and compose path. Dart source alone does not update nginx.
Generated build files are ignored by Git and must be built after a fresh clone.

## Inspect and stop safely

```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation ps
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation logs --tail=100 n8n engine
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation stop
```

Persistent named volumes retain n8n, PostgreSQL, and the synthetic engine database.
Never run down -v or delete volumes without intentionally approving data loss.
Back up the volumes and retain the original encryption key before migrating.
Docker Desktop and an awake device are required for local execution.
