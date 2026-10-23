# CareerFlow â€” progress tracker

Last updated: October 23, 2026 (Asia/Manila).

## Current checkpoint

- **Completed:** D1.1, D1.2 interactive session preview, UI refinement, local Docker deployment, D2.1 classification/matching, and D2.2 orchestration for synthetic data.
- **Current status:** D1.2 is complete and deployed locally. Stopped at the milestone for review.
- **Next:** D3.1 shared application database and frontend integration; stopped after D1.2 for review.
- **Gmail connection:** Not configured. Live ingestion and label updates are blocked on D3.2 OAuth/provider integration; no mailbox changes made.
- **Local URLs:** Web http://localhost:8087; n8n http://localhost:5678.
- **Runtime:** web, n8n, PostgreSQL, and private engine under project07-automated-career-opportunity-manager.
- **Database distinction:** PostgreSQL stores n8n state. The engine uses persistent SQLite only for this synthetic sprint; Flutter still shows fictional preview data.

## Milestone board

| Date | Milestone | Status | Evidence / remaining work |
|---|---|---|---|
| Oct 22 | P0 â€” Daily sprint plan and tracker | Complete | `SPRINT_PLAN.md` and this tracker created; milestone stop rule recorded |
| Oct 22 | D1.1 â€” Flutter foundation and visual shell | Complete | Static analysis clean; 6 tests passed; final web build succeeded; browser preview verified |
| Oct 23 | D1.2 - Interactive CRM screens | Complete (session preview) | 9 tests pass; clean analysis; release build, desktop/mobile browser checks and Docker deployment verified |
| Oct 23 | D2.1 â€” Email classification and matching | Complete (synthetic scope) | 20 regression tests pass, including a 16-case email fixture matrix; live templates unverified |
| Oct 23 | D2.2 â€” Workflow orchestration | Complete (synthetic scope); live checks blocked | Four installed workflows verified: three successful and one expected failure; real Gmail awaits D3.2 |
| Oct 24 | D3.1 â€” Database and app integration | Not started | Backend project and access configuration needed |
| Oct 24 | D3.2 â€” Gmail and label synchronization | Not started | Google OAuth connection and live verification needed |
| Oct 25 | D4.1 â€” Recovery and manual review | Not started | Depends on integrated application flow |
| Oct 25 | D4.2 â€” Action tracking | Not started | Depends on persisted tasks/events |
| Oct 26 | D5.1 â€” End-to-end verification | Not started | Depends on completed feature milestones |
| Oct 26 | D5.2 â€” Release and handover | Not started | Hosting scope and release checks needed |

## Verified facts

- Workspace was empty apart from `.git` before planning files were added.
- Flutter launcher found at `C:\Users\Guienne Jairo Reyes\dev\flutter\bin\flutter.bat`.
- Dart executable reported version 3.13.5.
- Flutter startup attempted an SDK Git metadata fetch; a subsequent project-creation command waited for the startup lock.
- Pending Flutter commands were interrupted when the user requested sprint planning. No generated application files were present.
- Dependency resolution succeeded with Flutter 3.47.7 / Dart 3.13.5.
- Static analysis completed with no issues. All 6 widget tests passed across desktop navigation and 360, 768, 1000, 1024, and 1440 pixel viewport widths, including a short window.
- Final release build succeeded with locally hosted renderer assets: `flutter --no-version-check build web --no-pub --no-web-resources-cdn --no-wasm-dry-run`.
- Browser preview rendered successfully at `http://127.0.0.1:8080`; navigation to Connections and back was verified. Screenshot saved in `screenshots/d1-1-dashboard.png`.

## Decisions

| Decision | Status |
|---|---|
| Flutter as the application framework | Confirmed by user |
| Web as the first platform | Confirmed by user |
| Daily sprints, website today and workflow tomorrow | Confirmed by user |
| Update tracker and stop at every completed milestone | Confirmed by user |
| Supabase/PostgreSQL and n8n integration | Planned architecture; configuration pending |

## Checkpoint log

### October 23 â€” UI refinement and Docker web checkpoint complete

- Applied impeccable distillation: removed motivational copy, decorative eyebrow labels, oversized metric cards, and sidebar promotional panel. Kept teal identity and all existing navigation.
- Flutter checks passed: 6 widget tests, static analysis, and release build. Impeccable mechanical detector returned no findings; its Dart coverage is limited, desktop and 390px mobile screenshots were subsequently inspected successfully.
- Started D2.1 draft engine/service. No classifier fixtures or orchestration tests have passed yet. D2.2 has no workflow exports yet.
- User requested local Docker and then explicitly invoked hands-on coaching. Changed execution style: prepare mechanical scaffolding, then let the user inspect the deployment before continuing workflow configuration.
- Target repository confirmed: JaiReyes45/AI-Automation-BasicProjects. Follow its projects/NN-name convention with folder 07-automated-career-opportunity-manager and exact Compose name project07-automated-career-opportunity-manager.
- No Gmail authorization, ingestion, or labeling has occurred. No GitHub push requested or performed.


### D1.1 â€” October 22, 2026 â€” Complete

- Created Flutter web project, stage/application models, repository interface, and immutable fictional examples.
- Added theme, responsive desktop sidebar/mobile drawer, dashboard summary, application previews, sample activity, and disconnected Gmail screen.
- Added launch instructions and web metadata.
- Initial verification caught Material paint issues, a cramped brand header, short-window overflow, and an ambiguous test locator. Corrected these before the final successful tests.
- Passed: dependency resolution; `flutter analyze`; 6 widget tests; final release web build; actual browser rendering and connection-screen navigation.
- Narrow/wide layout checks were automated; desktop rendering was also visually inspected in the browser.
- Preview server currently runs on localhost port 8080. To restart: `python -m http.server 8080 --bind 127.0.0.1 --directory build/web` from the project root after building.
- Limitations: read-only fictional data; no editing/filtering, durable database, Gmail authorization, or email automation yet.
- Stopped here as requested. Next milestone is D1.2; Day 1 is not yet fully complete.

### P0 â€” October 22, 2026

- Created the dated daily sprint plan and persistent tracker.
- Defined deliverables, acceptance checks, dependencies, and explicit stop points.
- Interrupted pending setup commands before implementation continued.
- Verification: reviewed both planning documents and workspace status.
- Next: on user continuation, work only on D1.1, verify it, update this tracker, and stop again.

## Update procedure

At each milestone, record:
1. Status: Not started / In progress / Blocked / Complete.
2. Actual completion date and changed files or artifacts.
3. Checks run and their results; distinguish unrun checks from passed checks.
4. Known limitations, blockers, and any schedule change.
5. The next milestone, then stop and report to the user.

Do not mark a milestone complete based only on generated code or elapsed time.


## Docker checkpoint evidence â€” October 23

- Canonical portfolio copy: `/home/guienne_jairo_reyes/code/AI-Automation-BasicProjects/projects/07-automated-career-opportunity-manager`.
- Working Windows copy retained; no source files were deleted. Future changes must be synchronized deliberately to avoid divergence.
- Root portfolio README now includes Project 07 as in progress. Changes are local and uncommitted; nothing was pushed to GitHub.
- Compose configuration validated before startup. Only `web` was started.
- Docker project: `project07-automated-career-opportunity-manager`.
- Container: `project07-automated-career-opportunity-manager-web-1` reported healthy.
- Port: `127.0.0.1:8087 -> 80`. Browser loaded CareerFlow from this port.
- Screenshots: `screenshots/refined-desktop.png`, `screenshots/refined-mobile.png`.
- `git diff --check` passed in the portfolio repository; generated web build is ignored by Git.
- PostgreSQL/n8n templates are present but inactive. Proposed n8n loopback port 5687 awaits user review before activation. No data volumes were deleted and no existing stacks were started/stopped.
- Hands-on task: open Docker Desktop, expand the Project 07 group, inspect web-1 health and port 8087, then open the app. Expected: healthy container, sample applications, Gmail disconnected.
- Next after that inspection: configure the isolated automation environment and verify D2.1 fixtures, then D2.2 workflow orchestration. These are not yet complete.


### October 23 â€” Docker checkpoint confirmed; D2.1 first fixture

- User confirmed the Docker-hosted website loads.
- Added `fixtures/application-submitted.json`, read-only `workflow/preview.py`, and `docs/d2-1-first-email.md`.
- Verified the first synthetic message returns submitted / QA Engineer Intern / Example Labs / APP-007, with evidence and proposed_action=create.
- Preview writes zero records and makes no network requests. This is a Python host diagnostic, not a deployed Docker workflow.
- Remaining D2.1 checks: missing fields, quoted text, conflicting signals, duplicate processing, stale updates, and application matching. No claim of full D2.1 completion.
- User task: run the preview command in Ubuntu/WSL and inspect stage, role, and evidence before the next exercise.


### D2.1 hands-on checkpoint â€” submission and missing details confirmed

- User confirmed the first submission fixture returns the expected fields.
- User confirmed the missing-details test returns stage=submitted, company=null, role=null, decision=unmatched_application.
- Prepared `workflow/preview_duplicate.py`: processes a synthetic message twice, reopens the store between deliveries, checks record counts, and removes its temporary database.
- Corrected Store.connect to explicitly close database connections after transaction completion.
- Agent verification passed outside the Windows sandbox (sandbox temporary SQLite access was denied): first_duplicate=false, second_duplicate=true, same_application=true; one application, event, message, and outbox job. No Gmail calls or live records.
- Next user task: run `python3 -m workflow.preview_duplicate` from the Project 07 folder and inspect the counts. Full D2.1 remains in progress; D2.2 not started.


### D2.1 milestone â€” October 23 â€” Complete for controlled fixtures

- User explicitly resumed autonomous execution through today's D2.1/D2.2 sprint.
- 20 regression tests pass, including a 16-case classification matrix and role aliases.
- Covered missing fields, quoted old text, conditional/negated language, conflicting fields, different roles at one company, new-thread reference matching, cross-account isolation, stale events, closed applications, concurrent duplicate delivery, and restart persistence.
- Added label-job tests: preserved unrelated labels, visible durable failure, recovery, retry cap, and current-stage synchronization.
- No real inbox/provider templates validated. Explicit labeled Company/Role/Reference fields are the supported fixture contract; unknown layouts are reviewed.
- D2.1 complete does not imply live Gmail support. Continue to D2.2 as authorized.
- n8n editor running at localhost:5678 under Project 07. The earlier proposed 5687 port was not activated; 5678 follows the repository rule and was free.
- User confirmed owner setup completed. Secret values remain only in the ignored local environment and n8n credential store.


### D2.2 milestone â€” October 23 â€” Complete for local controlled execution

- Installed four inactive workflows in Project 07 n8n 2.34.5; user completed local owner setup.
- Intake and simulated delivery succeeded. End-to-end test verified duplicate handling, interview progression, durable visible delivery failure, and successful retry. Invalid input reached the explicit failure branch after bounded HTTP retries.
- Evidence: docs/n8n-verification.json. Full raw execution output and runtime tokens are not committed.
- Container-restart persistence verified in docs/docker-persistence.json. Counts are a snapshot before later verification runs, not a permanent expected total.
- Final engine regression suite: 20 passing tests, including 16 classification cases and the negated-submission guard.
- Local service secrets generated in ignored .env and imported into n8n's encrypted credential store. Temporary credential import file removed. Existing encryption key preserved.
- Workflow exports contain only synthetic examples and non-secret credential references; they are inactive and not polling Gmail.
- API is internal to Docker and accepts only synthetic account domains. Mock labels preserve unrelated labels and use the latest application stage when retrying old jobs.
- Updated setup/import/verification scripts, contract, Docker documentation, and portfolio status. No GitHub push and no data-volume deletion.
- Remaining: real Gmail adapter and OAuth, database migration and frontend connection, production retries/reconciliation, manual-review UI, and D1.2 interactions. These were not silently counted as completed.

### D1.2 milestone - October 23 - Complete for session preview

- Implemented search, combined role/stage filters, add/edit validation, application details, manual stage history and independent next actions.
- Stable IDs preserve separate applications at the same company; canceled edits do not mutate records.
- Nine Flutter tests passed; static analysis clean; release web build successful. Browser creation flow and desktop/mobile rendering verified.
- Deployed to Project 07 web on localhost:8087; frontend remains separate from the synthetic workflow engine. Refreshing resets all edits.
- Evidence: docs/d1-2-verification.md and desktop/mobile screenshots. No Gmail access, GitHub push, or volume deletion.
- D1.2 and Day 1 UI scope complete. Next: D3.1 persistent database integration. Stopped for review as requested.


### Profile and design milestone — October 23

- Added restrained warm-neutral styling, updated shared controls, and Profile navigation.
- User selected local Docker folder storage with optional Drive links. Added persistent profile fields, document uploads/downloads, and named requirement links.
- Local profile storage is separate from session-only applications; shared application persistence remains D3.1.
- Verification: 9 existing widget tests plus 3 profile tests passed; synthetic profile service checks passed, including server restart persistence. See docs/profile-storage.md.
- Deployed web/profile containers. No Google OAuth, mailbox changes, or GitHub push. Stop at this milestone for review.


### GitHub publication checkpoint - October 23

- User authorized committing and pushing, matching the preceding portfolio projects.
- Kept the numbered project folder; separated screenshots and diagrams; aligned README status, problem, behavior, stack, layout, workflow map, setup, validation and limitations.
- Reviewed publishable files and excluded local secrets/data/builds. Prior no-push entries describe earlier checkpoints.
