# CareerFlow local hand-off — 1.1.0

Updated October 28, 2026 for one user on a trusted Windows/WSL Docker device.

The follow-through update adds Today, evidence-linked requests, Windows desktop alerts, capture coverage, quick capture and private interview reminders. Read [the follow-through guide](docs/follow-through-guide.md) for daily use and the current verification boundary. The existing workspace password is unchanged.

## Open your workspace

- CareerFlow: http://localhost:8087
- Workflow editor: http://localhost:5678
- Your workspace password is the existing `CAREERFLOW_APP_PASSWORD` in the project's private `.env`. The n8n owner account is separate.
- Keep Docker Desktop running and the device awake for five-minute Gmail polling.

## Delivered scope

| Area | What is available |
|---|---|
| Applications | Persistent company/role records, search, filters, stage edits and history |
| Email review | Read evidence; link to an application, create one, keep an opportunity or dismiss; revision checks and recorded decisions |
| Actions | Optional due dates, categories, complete/reopen controls and follow-up suggestions |
| Profile | Personal/professional links, internship requirements, local uploads and optional Drive links |
| Automation | Recent career-email intake, conservative matching, duplicate protection, managed Gmail labels and delivery readback |
| Operations | Connection timestamps, visible failed deliveries, bounded retries, sign-out and verified private backups |
| Workspace 1.1 | Duolingo-inspired journey, submission-date filtering/sorting, descriptions, email detail and top-right profile/photo |
| Calendar and assistant | Primary Google Calendar sync, local Qwen chat and explicit previews for edits/replies/meetings |

Completing an action does not advance an application. There are no invented hiring probability scores. Ambiguous evidence needs a review decision.

## Guides

1. [Daily use](docs/user-guide.md)
2. [Installation and container operations](docs/docker-setup.md)
3. [Backup and recovery](docs/backup-recovery.md)
4. [Release verification and acceptance boundary](docs/release-verification.md)
5. [Architecture](diagrams/architecture.md) and [sprint tracker](PROGRESS_TRACKER.md)
6. [Workspace 1.1, local assistant and Calendar setup](docs/workspace-1.1.md)

## Acceptance boundary

Controlled progression and recovery pass. Five genuine application confirmations and scheduled Gmail label delivery were verified. Calendar reading and the local assistant's count query pass. No real test reply or invitation was sent; verify the first intentional send/booking in Google. A genuine subsequent employer email has not yet safely matched and advanced an application; that field-acceptance check remains open. Do not force a match to close it.

Capture now scans received and Sent mail within its displayed time coverage, excluding drafts, spam and trash, rather than relying on a career-keyword subject filter. Conservative extraction still requires manual review for unfamiliar formats; applications without an email require quick capture. Public hosting, multiple users, mobile packaging, attachment extraction, school Drive OAuth, document deletion/versioning and calibrated hiring predictions are outside this release. Drive links use their existing sharing permissions.

## Transfer checklist

- Source lives under `projects/07-automated-career-opportunity-manager` in the portfolio repository, following the existing project layout.
- The release ZIP contains source, documentation and the built web client, but no accounts, passwords, emails, uploads or database backups.
- Private backups stay in `.runtime/backups` on the current device. Transfer them separately through a private channel only when migrating the same user's workspace.
- A new user's installation must generate its own settings and connect its own Gmail account.
- Preserve the original encryption key when restoring this workspace. A source checkout alone cannot recover its credentials or data.

## Patch 1.0.1 — October 26

Automatic workspace refresh and Indeed HTML confirmation parsing are deployed. Two real confirmations were recovered (five total applications). Current regression totals: 22 Flutter tests, 38 parser/engine tests, exported MIME-normalizer check and CRM integration checks. The original release's genuine follow-up progression caveat remains unchanged.
