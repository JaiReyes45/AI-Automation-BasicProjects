# CareerFlow — daily sprint plan

Created: October 22, 2026. All dates use Asia/Manila time.

## Objective

Build a personal Flutter web application that organizes Gmail career emails into applications, role categories, hiring stages, and next actions. Maintain an evidence-backed application history. Do not present unsupported hiring probabilities.

## Working agreement

- Work in daily sprints, beginning with the website today and the workflow tomorrow.
- Dates are planning targets, not promises or scheduled background runs. Resume work when the user asks; carry unfinished work forward explicitly.
- At each milestone: perform its checks, update `PROGRESS_TRACKER.md`, report the result and remaining limitations, and stop for user review before the next milestone.
- A milestone is complete only when its acceptance checks pass. Record blockers and partial work honestly.
- Planning is complete; implementation has not started. Environment inspection found Flutter and Dart, but the Flutter startup check did not finish. The pending commands were stopped before project files were generated.

## Planned architecture

- Frontend: Flutter web, responsive for desktop and mobile browsers.
- Data: repository interface in Flutter; clearly marked sample data for the first UI milestone, followed by durable backend storage.
- Target backend: Supabase/PostgreSQL for applications, messages, events, tasks, and review items.
- Workflow: n8n for Gmail ingestion, classification, application matching, database updates, and label synchronization.
- Gmail authentication: Google OAuth, configured during the workflow/integration sprints. No OAuth secrets in Flutter code.
- Classification: conservative rules first; an AI fallback can follow after representative examples are validated.
- Initial responsiveness: polling. Near-real-time Gmail push is a later enhancement.
- Gmail automation runs separately from the Flutter app so closing the browser does not stop a deployed worker.

## Day 1 — Thursday, October 22: Flutter website

Goal: a runnable, interactive web interface whose sample-data status is obvious.

### D1.1 — Project foundation and visual shell

Deliver:
- Resolve Flutter startup and create the web project.
- Establish models, repository boundaries, theme, responsive navigation, and an application dashboard shell.
- Include explicit sample-data and Gmail-not-connected indicators.

Acceptance:
- Flutter dependency resolution and static analysis succeed.
- The app builds for web and opens locally.
- Main navigation and narrow/wide layouts are checked.

Checkpoint: update the tracker and stop.

### D1.2 — Interactive CRM screens

Deliver:
- Application list/board, search, role filters, stage filters, and application details.
- Add/edit an application and change its stage in the preview repository.
- Show event history and next action separately from hiring stage.
- Include empty states and clear validation errors.

Acceptance:
- Creating an application, filtering it, opening it, and changing its stage works.
- Two roles at one company remain separate applications.
- Sample data and any session-only persistence limitation are visible; no implied live Gmail connection.
- Relevant widget/domain tests pass.

Checkpoint: update the tracker and stop. Day 1 is complete after both milestones pass.

## Day 2 — Friday, October 23: Email workflow

Goal: build and verify the ingestion/classification workflow using controlled examples first.

### D2.1 — Email classification and matching

Deliver:
- A documented email/event schema and representative synthetic fixtures.
- Detect submissions, reviews, information requests, assessments, interviews, offers, and rejections.
- Normalize role titles; preserve the original title.
- Distinguish job recommendations from submitted applications.
- Define duplicate detection, conservative matching, and manual-review routing.

Acceptance:
- Fixture checks cover duplicates, missing roles, quoted old text, different roles at one company, new-thread replies, and out-of-order updates.
- Missing fields stay unknown rather than being invented.
- Ambiguous events cannot silently change an application.

Checkpoint: update the tracker and stop.

### D2.2 — Workflow orchestration

Deliver:
- n8n workflow definition for ingestion, parsing, matching, storage, and Gmail-label updates.
- Explicit retry/error paths and a configuration guide.
- Separate workflow validation from real-account validation.

Acceptance:
- Controlled messages traverse the configured test workflow without duplicate records.
- A failure is visible and retryable.
- If a workflow runtime or Google credentials are unavailable, mark runtime/live checks blocked rather than declaring them passed.

Checkpoint: update the tracker and stop.

## Day 3 — Saturday, October 24: Storage and live integration

Goal: connect the website and workflow to the same durable application records.

### D3.1 — Database and application integration

Deliver:
- Schema/migrations for applications, messages, message links, events, tasks, and review items.
- Authentication/access rules and the Flutter repository implementation.
- Loading, retry, and failure states in the website.

Acceptance:
- Changes survive a browser reload and backend restart where applicable.
- Unauthenticated/unauthorized access is denied.
- Stage changes preserve event history and source evidence.

Checkpoint: update the tracker and stop.

### D3.2 — Gmail connection and label synchronization

Deliver:
- Configure the user's Google OAuth connection and selected mailbox scope.
- Enable ingestion and label synchronization on a small, agreed test set.
- Show actual connection status and last successful synchronization in the app.

Acceptance:
- An actual application email creates or matches the correct record.
- A subsequent employer update advances that record and synchronizes its labels.
- Tokens stay outside frontend code and repository files.
- Credential setup and any required user interaction are completed before claiming live integration works.

Checkpoint: update the tracker and stop.

## Day 4 — Sunday, October 25: Reliability and actions

Goal: recover from failures and make the next action clear.

### D4.1 — Recovery and review

Deliver:
- Durable deduplication, retries, reconciliation, and a manual review/correction flow.
- Protect confirmed stages against stale or ambiguous updates.

Acceptance:
- Reprocessing the same message causes no duplicate application/event.
- A temporary Gmail/database failure recovers without losing work.
- Manual corrections remain traceable.

Checkpoint: update the tracker and stop.

### D4.2 — Action tracking

Deliver:
- Reply-needed, assessment-due, interview-scheduling, and follow-up views.
- Dates displayed in Asia/Manila; unknown deadlines remain unknown.
- Evidence-based progress groups rather than invented probability percentages.

Acceptance:
- Completing an action does not incorrectly advance the hiring stage.
- Silence can flag follow-up but never automatically means rejection.
- Offer received, offer accepted, and hired remain distinct.

Checkpoint: update the tracker and stop.

## Day 5 — Monday, October 26: End-to-end validation and release

Goal: a usable personal MVP with a documented operating procedure.

### D5.1 — End-to-end verification

Deliver:
- Full flow checks from submission through interview/offer/closure.
- Responsive UI verification, error-state checks, and operating documentation.

Acceptance:
- The app and workflow agree on current stage, role, history, and next action.
- Critical checks pass; remaining issues are documented with impact.
- No example data or disconnected state is mistaken for live activity.

Checkpoint: update the tracker and stop.

### D5.2 — Release and handover

Deliver:
- Selected frontend/backend/workflow hosting configuration.
- Environment-variable instructions, restart/recovery steps, and a data backup procedure.
- A working URL or reproducible local launch procedure, depending on the chosen hosting scope.

Acceptance:
- The target deployment is verified, including its actual background-workflow availability.
- Any paid hosting or external publication decision is explicit before provisioning/publication.
- Remaining limitations and future enhancements are recorded.

Checkpoint: update the tracker and stop.

## Dependencies and scope boundaries

- The planned dates may move if SDK setup, OAuth setup, hosting decisions, or account access takes longer.
- Day 1 uses samples; live Gmail processing is not a Day 1 completion criterion.
- Workflow authoring can begin with fixtures before live credentials are available.
- No auto-replies, automatic job applications, or automatic acceptance of offers in the MVP.
- Defer calibrated hiring predictions, Gmail push notifications, attachments/OCR, mobile packaging, and multi-user support until the core flow is reliable.

## Definition of done for the MVP

A genuine application email appears as the correct application in the Flutter website; subsequent messages update that same application, Gmail labels stay synchronized, history and next actions are visible, ambiguous messages are reviewable, and duplicate/failure recovery is verified.


## October 23 scope update

User requested an impeccable UI refinement, continuation toward D2.1–D2.2,
local Docker deployment, and then explicitly switched to hands-on coaching.
UI refinement and the isolated web container are verified. Workflow work resumes
one meaningful stage at a time after the user's container inspection. D1.2 is
still pending. Project 07 follows the portfolio repository's folder convention,
with the exact requested Compose project name. PostgreSQL is the planned local
backend; Supabase is no longer required for local operation. The current draft
SQLite adapter is only an unverified workflow prototype, not the final backend.


## October 23 completion checkpoint

User resumed autonomous execution for the rest of Day 2. D2.1 and D2.2 are
verified for controlled synthetic data; live Gmail checks are explicitly blocked
until D3.2. Four inactive n8n workflows are installed and visible in Docker's
Project 07 environment. See PROGRESS_TRACKER.md and docs/d2-verification.md.
The D1.2 interface milestone remains outstanding. No automatic scheduled wakeup
or next-day work was configured.


## October 23 D1.2 checkpoint

D1.2 is complete for the session-only preview: application CRUD (add/edit), search, role/stage filters, details, event history, and independent next-action editing are verified. Nine tests pass; desktop/mobile browser checks and Docker web deployment passed. Day 1 UI scope is complete. Stop for review; D3.1 shared persistent storage is next.
