# Project 07 - Automated Career Opportunity Manager

CareerFlow is a local-first internship and job-application CRM built with Flutter,
n8n, Python, and Docker.

## Status

**Implemented locally; synthetic workflows and interactive UI verified.** Last reviewed: 2026-10-23.

12 Flutter tests and 20 engine tests pass. Profile storage checks cover saving,
document delivery, validation and server-restart persistence. Four inactive n8n
workflows are verified: three succeed and one deliberately fails on invalid input.
Live Gmail and the shared application/workflow database remain pending.

## Business problem

Application confirmations, employer updates, and internship requirements are
scattered across inboxes and folders. CareerFlow organizes roles, hiring stages,
next actions, personal details, professional links, and school documents without
inventing hiring probabilities.

## Implemented behavior

- Search and filter applications by company, role, source and stage.
- Add/edit distinct applications, preserve manual history, and track next actions.
- Save profile details and internship requirements in a local Docker folder.
- Upload/download PDF, DOCX, PNG and JPG files up to 8 MB; save external Drive links.
- Classify controlled email fixtures, match applications, and prevent duplicates.
- Demonstrate simulated label delivery, visible failures and bounded recovery.

Application edits are session-only. Profile data and uploaded documents persist.
Google Drive links do not connect an account or change sharing permissions.

## Implemented stack

- Flutter web served by nginx on loopback port 8087.
- Python profile service with SQLite metadata and local document files.
- n8n 2.34.5 on loopback port 5678; PostgreSQL 16 stores n8n state.
- Private Python synthetic workflow engine with persistent SQLite test storage.
- Isolated Compose project: `project07-automated-career-opportunity-manager`.

See the [architecture diagram](diagrams/architecture.md).

## Repository layout

| Directory | Contents |
|---|---|
| `docs/` | Setup, contracts, storage instructions and verification evidence |
| `diagrams/` | Current architecture and integration boundaries |
| `screenshots/` | Reviewed synthetic desktop/mobile UI evidence |
| `lib/`, `web/`, `test/` | Flutter sources, web bridge and widget tests |
| `profile_service/`, `workflow/` | Local profile API and synthetic classification engine |
| `fixtures/`, `tests/`, `scripts/` | Synthetic fixtures, regression tests and operator tools |
| `workflows/` | Four inactive n8n exports with non-secret credential references |
| `docker/` | Container build files and nginx configuration |

## Workflow map

| Workflow | Responsibility |
|---|---|
| 01 | Synthetic email intake, classification and matching |
| 02 | Simulated label delivery |
| 03 | Duplicate handling, interview progression and recovery scenario |
| 04 | Expected invalid-input failure |

Exports contain synthetic examples, no execution data or secret values. Configure
local credentials using the setup guide before running them.

## Start here

1. Read the [Docker setup guide](docs/docker-setup.md).
2. Review the [workflow contract](docs/workflow-contract.md) and [profile storage guide](docs/profile-storage.md).
3. Inspect the [UI verification](docs/d1-2-verification.md) and [workflow verification](docs/d2-verification.md).
4. Follow the [progress tracker](PROGRESS_TRACKER.md) for milestone scope and remaining work.

## Validation

From this project directory:

```bash
python3 -m unittest discover -s tests -v
python3 tests/profile_storage_check.py
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

Run Docker commands from the portfolio repository root with the explicit project
Compose file and environment file, as documented. Recorded n8n results are in
[verification JSON](docs/n8n-verification.json).

## Known limitations

- Application records reset on browser refresh; the shared database is D3.1.
- Gmail OAuth, live ingestion and real label synchronization are not implemented.
- Email classification supports controlled fixtures, not arbitrary employer templates.
- Profile storage is plain local storage, not encrypted storage or a backup.
- No login layer: the app is for a trusted single-user device, not public hosting.
- Document deletion/version management, manual-review UI, production backoff and
  reconciliation remain future work. Uploaded documents are not parsed.
- Local secrets, profile records, uploads, databases and generated builds are ignored.
