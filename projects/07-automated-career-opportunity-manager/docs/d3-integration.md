# Day 3 integration - October 24, 2026

## Persistent workspace

Flutter uses the authenticated PostgreSQL CRM, with application revisions, next actions and append-only history. It does not seed sample applications. Profile metadata and documents remain in the separate local folder. The old synthetic SQLite engine is retained for controlled tests.

The workspace password is CAREERFLOW_APP_PASSWORD in the ignored Project 07 .env file. After changing it, recreate the crm service; restarting alone does not reread Compose environment values. Sessions use a 12-hour HttpOnly, SameSite=Strict cookie. Internal workflow routes require the service credential and are not exposed through nginx. This remains a trusted, single-user, loopback-only deployment.

## Live workflow

- 05 prepares the managed Gmail labels. It remains manually runnable.
- 06 imports incoming career emails from a rolling seven-day window. It follows Gmail page tokens, with 10 results per page and a maximum of 20 pages. Exceeding 200 matches fails explicitly rather than silently skipping older pages.
- The query includes application, interview, internship, assessment, shortlisted, job-offer and additional-information subjects. It excludes sent mail, drafts, promotions and common job-alert subjects/senders. This is a bounded subject filter, not a guarantee of finding every possible employer message.
- Already processed messages are skipped. Unlinked messages are reconsidered after a parser upgrade. New messages are ingested oldest first; stale events and stage regressions cannot overwrite current progress.
- 07 independently claims up to 25 eligible label jobs, applies the current stage/role labels, reads Gmail labels back and acknowledges only verified results.
- Intake and reconciliation are published with five-minute schedules. Docker, n8n and the device must be running. Flutter displays refreshed records after reloading the workspace.
- Exported JSON files remain inactive for safe import into another installation. Publishing and a restart are explicit local deployment actions.

Only Career/Stage/*, Career/Role/* and Career/System/Needs Review labels are removed or replaced. Other Gmail labels are preserved. No mail is sent, deleted, archived or marked read.

## Identity and recognition

The parser supports explicit JobStreet confirmations, including wider internship titles. A Gmail conversation can contain confirmations for different companies or roles, so an explicit confirmation is matched using the account, conversation, exact company and original role. Its derived reference is internal and is not an employer-issued application ID.

Indeed confirmations without an employer and Workday confirmations without a stable matching reference stay in review. Shortlisting, assessment invitations and wrapped rejection wording are recognized, but they advance a record only when matching is unambiguous. A closed JobStreet listing does not imply application rejection. Generic follow-ups in a shared multi-application thread remain ambiguous.

Original role titles are retained. Known role groups have dedicated labels; other internship titles use Career/Role/Other Internship. No hiring probability is fabricated.

## Recovery and status

Label jobs persist in PostgreSQL. Claiming reserves a job for ten minutes. Failures use exponential delays and a six-attempt limit; a missing Gmail message becomes a visible failed job. Jobs carry a generation and attempt number, so an older response cannot acknowledge a newer stage. Manual stage/role changes requeue previously linked messages. Only messages within the authorized seven-day window are delivered by the worker.

Earlier broad-query jobs remain stored, but are excluded from delivery until selected by the focused career query. At this checkpoint, 87 legacy jobs are excluded and 17 eligible jobs are delivered.

Authenticated GET /api/crm/status exposes last_sync_completed, last_sync_processed, last_label_check, review_count and label_jobs counts. last_checked means the Gmail account check succeeded; it is not a full-sync timestamp. Failed-job operator controls and a review-resolution UI are D4 work. A disconnected/expired OAuth credential requires reconnecting in n8n; do not repeatedly retry a broken grant.

## Verification and acceptance

- 35 engine/provider tests pass, including mixed-application threads, ambiguous follow-ups, spoofed provider domains, footer disclaimers, unknown internship titles and missing identities.
- crm.verify checks sign-in, service authentication, persisted application/history changes, duplicate delivery and stale edits.
- crm.verify_sync checks leases, account isolation, retry backoff/success/caps, stale acknowledgements, application progression and the seven-day boundary inside a rolled-back synthetic transaction.
- Live intake followed two Gmail pages and found 17 matching messages. The improved matcher recovered a third confirmed application. Repeated intake imported zero messages and created no duplicate applications.
- Eligible Gmail label jobs were verified by readback: 17 delivered, none pending/failed at the checkpoint. Public evidence contains only counts and timestamps.
- The previous 12 Flutter tests, clean analysis and release build remain the frontend baseline; this sprint changed backend/workflow behavior, not Flutter source.

D3.1 is complete. D3.2's scheduled intake/reconciliation implementation is deployed; automatic execution evidence is recorded in docs/d3-scheduled-verification.json. Full real-world progression acceptance remains open: no safely matched genuine follow-up has yet advanced an existing application. Synthetic progression passes; unmatched real messages were not forced into an application.

## Operations

Run Docker commands from the portfolio repository root. Replace neither the encryption key nor existing credentials.

Validate Compose:
```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml config --quiet
```

After a workspace-password change:
```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml up -d --no-deps --force-recreate crm
```

View aggregate status:
```bash
python3 projects/07-automated-career-opportunity-manager/scripts/check_sync_status.py
```

Pause syncing by unpublishing workflows 06 and 07 in the n8n editor. For CLI use n8n unpublish:workflow --id=project07GmailSync and --id=project07GmailReconcile, then restart only the n8n service. Do not delete volumes. Reimporting exports can unpublish them; explicitly publish after review and restart when using the CLI.

OAuth setup: Google Auth Platform External / Testing, Gmail account as a test user, Gmail API enabled, Web client redirect http://localhost:5678/rest/oauth2-credential/callback. Credentials stay encrypted in n8n. Google testing grants may require reconnection; inspect the credential locally if authorization stops.

References:
- [Gmail list pagination](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/list)
- [n8n HTTP pagination](https://docs.n8n.io/build/code-in-n8n/cookbook/http-request-node/pagination/)
- [n8n CLI publishing and restart](https://docs.n8n.io/hosting/cli-commands/)


Automatic runs were observed on October 24 at 23:00 Manila: the intake completion timestamp advanced and reconciliation recorded its queue check, with trigger-mode n8n entries. Because execution payload saving is disabled, n8n soft-deletes completed entries without updating their old running field; these discarded entries are not evidence of an active execution. The aggregate status script marks them not_retained and reports the CRM completion timestamps separately.
