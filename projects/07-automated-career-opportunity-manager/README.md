# Project 07 - Automated Career Opportunity Manager

CareerFlow is a local-first internship and job-application CRM built with Flutter,
n8n, Python, and Docker.

## Status

**Local client hand-off release 1.1.0.** Reviewed: 2026-10-26.

Application CRM, review decisions, dated actions, profile/document storage, scheduled
Gmail intake and label recovery are implemented, along with the [unified workspace](docs/workspace-1.1.md): submission dates, email details, profile photo, Google Calendar and local Ollama assistant. Start with [HANDOFF.md](HANDOFF.md).
The release has 27 passing Flutter tests and 38 engine/provider tests, API acceptance
checks and a verified isolated backup restore. Genuine employer follow-up progression
remains a field-acceptance item; controlled submission-to-hired progression passes.

## Business problem

Application confirmations, employer updates, and internship requirements are
scattered across inboxes and folders. CareerFlow organizes roles, hiring stages,
next actions, personal details, professional links, and school documents without
inventing hiring probabilities.

## Implemented behavior

- Search company, role, source and saved job description; filter submission dates and stage, with newest/oldest ordering.
- Follow rounded journey cards, open linked email text, and access your profile/photo from the top-right avatar.
- Sync Google Calendar; preview and explicitly confirm replies, meetings and assistant-proposed edits.
- Add/edit distinct applications, preserve manual history, and track next actions.
- Save profile details and internship requirements in a local Docker folder.
- Upload/download PDF, DOCX, PNG and JPG files up to 8 MB; save external Drive links.
- Classify controlled email fixtures, match applications, and prevent duplicates.
- Import recent career emails automatically; retain uncertain application matches for review.
- Resolve uncertain emails by linking, creating, dismissing or saving an opportunity, with evidence and audit history.
- Track dated actions, complete/reopen them, and keep hiring stages independent of task completion.
- Verify Gmail stage/role labels by readback, with durable leases, bounded retries and visible recovery controls.
- Back up the private local workspace and verify restoration into an isolated database.

Application edits now persist in PostgreSQL behind local workspace sign-in. Profile data and uploaded documents persist separately.
Google Drive links do not connect an account or change sharing permissions.

## Implemented stack

- Flutter web served by nginx on loopback port 8087.
- Python profile service with SQLite metadata and local document files.
- n8n 2.34.5 on loopback port 5678; PostgreSQL 16 stores n8n state and the career schema.
- Private Python CRM API with workspace sessions and revision checks.
- Private Ollama container running Qwen3 4B for bounded local chat and action proposals.
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
| `crm/`, `database/`, `profile_service/`, `workflow/` | Shared CRM API/schema, profile API and synthetic engine |
| `fixtures/`, `tests/`, `scripts/` | Synthetic fixtures, regression tests and operator tools |
| `workflows/` | Nine portable, inactive exports; local workflows 06/07/08/09 are published |
| `docker/` | Container build files and nginx configuration |

## Workflow map

| Workflow | Responsibility |
|---|---|
| 01 | Synthetic email intake, classification and matching |
| 02 | Simulated label delivery |
| 03 | Duplicate handling, interview progression and recovery scenario |
| 04 | Expected invalid-input failure |
| 05 | Prepare managed Gmail labels |
| 06 | Five-minute Gmail intake, pagination and duplicate filtering |
| 07 | Five-minute Gmail label reconciliation and readback |
| 08 | One-minute worker for explicitly confirmed Gmail replies |
| 09 | Five-minute primary Calendar sync and explicitly confirmed meetings |

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
python3 scripts/finalize_web.py
```

Run Docker commands from the portfolio repository root with the explicit project
Compose file and environment file, as documented. Recorded n8n results are in
[verification JSON](docs/n8n-verification.json).

## Known limitations

- Shared application persistence is verified; see [Day 3 integration](docs/d3-integration.md).
- Gmail OAuth, pagination, intake and automatic label reconciliation are verified; a real matched follow-up advancing an application is still unverified.
- Unknown provider layouts or ambiguous identities stay in review; the seven-day subject filter is not a complete mailbox backfill.
- Profile storage is plain local storage, not encrypted storage or a backup.
- Local workspace sign-in is implemented; the app remains for a trusted single-user device, not public hosting.
- Document deletion/version management and document parsing are outside this release. Review and retry controls are implemented.
- Syncing requires Docker/n8n running; OAuth credentials can require reconnection. See [Day 3 operations](docs/d3-integration.md).
- Local secrets, profile records, uploads, databases and generated builds are ignored.

## October 26 sync fix

The live view now refreshes saved data every 30 seconds and when the tab resumes, with edit protection and visible connection errors. Indeed multipart confirmations retain HTML text as well as the plain part; verified employer/title evidence can create an application without guessing. Reprocessing the authorized seven-day window recovered two confirmed applications, bringing the verified total to five. Messages without sufficient identity still remain in review.
