# Local Docker installation and operations

Use Docker Desktop with WSL2 integration and Python 3. Run Compose commands from the portfolio repository root. Only this project's containers are managed. Ports 8087 and 5678 must be available. PostgreSQL and service APIs remain private to the Docker network.

## New installation

A source clone needs Flutter 3.47.7 (Dart 3.13.5) to build the client. The release ZIP already includes `build/web` and does not require Flutter just to start it.

From the project directory, for a source clone:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --no-web-resources-cdn --no-wasm-dry-run
```

Return to the repository root:

```bash
python3 projects/07-automated-career-opportunity-manager/scripts/setup_local.py
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation config --quiet
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation up -d --build --wait
```

Setup generates four private values only when absent and preserves existing keys. Read `CAREERFLOW_APP_PASSWORD` locally in `.env`; never paste the file into a public issue. Open http://localhost:8087. The separate n8n owner account is created at http://localhost:5678. Internet access is needed for initial dependencies, Docker images and Gmail; the built client assets are served locally.

## Gmail on a new installation

The supplied exports are inactive and contain credential references, not connected accounts. Complete local n8n owner setup first.

```bash
python3 projects/07-automated-career-opportunity-manager/scripts/import_n8n.py
python3 projects/07-automated-career-opportunity-manager/scripts/verify_n8n.py
```

The importer imports seven workflows and the local service-header credential via a temporary private file, then removes that file. Reimporting replaces matching workflow IDs; export intentional editor changes first. Workflows 01–04 are synthetic checks, including an expected invalid-input failure in 04.

Create a Google Cloud Web OAuth client with Gmail API enabled. Configure an External testing audience and add your Gmail address as a test user. Set the redirect URI to `http://localhost:5678/rest/oauth2-credential/callback`. Enter the client details only in an n8n Gmail OAuth2 credential and connect your account. An Internal audience blocks personal Gmail accounts with `org_internal`.

In every Gmail credential selector in workflows 05, 06 and 07, select your new credential; the exported ID belongs to the original local installation and will not exist in a fresh one. Keep the existing local engine-header credential on internal CRM requests. Save the workflows. Run 05 once to prepare managed labels, then manually test 06 (intake) and 07 (delivery). Inspect Connections and your Gmail labels before publishing.

Publish **06 and 07 only**, using their five-minute schedules. A fresh installation is not connected until this OAuth and workflow setup is complete. Google testing grants may require reconnection. See [Day 3 integration](d3-integration.md) for identity and delivery details.

## Normal operation

Docker and an awake device are required. Intake searches the last seven days of focused career subjects, follows pages up to 200 messages, and fails explicitly if that cap is exceeded. No mail is sent, deleted, archived or marked read. Only managed Career labels are changed. The exports stay inactive for portability; the original installation has 06/07 published.

```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation ps
python3 projects/07-automated-career-opportunity-manager/scripts/check_sync_status.py
```

Stop safely:

```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile automation stop
```

Restart with the installation `up -d --wait` command. Do not use `down -v`: it deletes persistent volumes. To pause mail automation while keeping the app available, unpublish workflows 06 and 07 in n8n.

## Updates and password changes

Back up before an update. Build Flutter after Dart/web changes, then rebuild the web service. Source changes alone do not update the served app.

```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml config --quiet
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml up -d --no-deps --build --wait crm web
```

To change the workspace password, edit only `CAREERFLOW_APP_PASSWORD` in the private `.env` and recreate CRM:

```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml up -d --no-deps --force-recreate --wait crm
```

A container restart alone does not reload changed environment values. Existing sessions remain valid until expiry/sign-out; password rotation is not a global session revocation feature. Preserve `N8N_ENCRYPTION_KEY`, `POSTGRES_PASSWORD` and the workflow token on an existing installation. Changing these requires a planned migration.

If the web proxy returns 502 after recreating backend containers, restart this project's web service to refresh its internal DNS resolution. Check Docker health before retrying sign-in. For expired OAuth, reconnect the Gmail credential in n8n and verify the next completion timestamp; repeated label retries cannot repair a broken grant.

See [backup and recovery](backup-recovery.md) before moving data. This release is bound to loopback for a trusted personal device; it is not configured for public hosting.
