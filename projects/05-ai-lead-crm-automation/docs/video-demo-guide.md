# Video Demo Guide — AI Lead-to-CRM Automation

## 1. What you are demonstrating

This project receives a synthetic sales lead, validates it, stores it, extracts
structured facts with a local AI model, calculates a deterministic score, routes
ambiguous cases to a person, and queues reliable CRM/notification work.

The key message for viewers is: **AI interprets text, but ordinary code and
database rules make the business decisions.**

## 2. Before recording

### Terminal — start the isolated environment

Open Ubuntu and go to:

```text
/home/guienne_jairo_reyes/code/lead-crm-demo
```

Run `docker compose ps`. Expect four Project 05 containers: n8n, PostgreSQL,
Ollama, and Mailpit. Do not show the `.env` file.

### Brave — open n8n

Visit `http://127.0.0.1:5679`. Keep every workflow inactive during the recorded
walkthrough unless you have deliberately reviewed and published the required
sub-workflows. Manual execution is enough for the portfolio demo.

### Privacy check

Use only addresses ending in `.test`, synthetic phone numbers, and fictional
company names. Hide browser tabs, notifications, tokens, credentials, and your
real Gmail/HubSpot account details.

## 3. Suggested opening narration

“This is an isolated AI lead-to-CRM automation built with n8n, PostgreSQL,
Ollama, and Docker. It uses a local language model only to extract facts from a
lead message. Validation, scoring, duplicate handling, routing, retries, and
audit history are deterministic and stored in PostgreSQL.”

## 4. Workflow-by-workflow walkthrough

### Workflow 10 — Webhook Lead Adapter

Show these nodes from left to right:

1. **Receive Website Lead** accepts an HTTP POST.
2. **Extract Lead Body** removes the surrounding webhook metadata.
3. **Run Lead-to-CRM Orchestrator** passes the lead into the internal pipeline.
4. **Build HTTP Response** maps internal outcomes to safe status codes.
5. **Return Lead Intake Result** returns JSON to the caller.

Say: “The public webhook is a thin adapter. Business logic lives in reusable
sub-workflows, so Gmail or another form can call the same pipeline.”

### Workflow 01 — Intake, Validation, and Persistence

Explain the path:

- Normalize names, email, phone, URL, and other fields.
- Validate the UUID, email, consent, required fields, and allowed source.
- Hash the normalized payload.
- Check whether the submission ID already exists.
- Same ID plus same hash means a safe idempotent repeat.
- Same ID plus different hash means a conflict requiring review.
- A new valid lead is stored as `AI_PENDING`.

Say: “Idempotency means retrying the same request does not create duplicate
records.”

### Workflow 02 — Local AI Extraction and Validation

Show:

1. **Build Guarded Ollama Request** treats the lead message only as data.
2. **Call Local Ollama** uses `qwen2.5:3b` inside Docker.
3. **Strictly Validate Extraction** accepts only the documented JSON shape.
4. An invalid response receives exactly one repair attempt.
5. A second failure becomes `REVIEW_REQUIRED`; it never reaches scoring.
6. A valid response is stored and moves to `SCORING`.

Point out that the expected fields are service category, timeline,
decision-maker status, country, summary, and confidence.

### Workflow 03 — Deterministic Scoring and Routing

Show the score-calculation node and its output table.

Explain that the 100 points come from published rules: service 25, budget 20,
company size 15, timeline 15, authority 10, business email 10, and Philippine
fit 5. HOT is 70–100, WARM is 40–69, and COLD is 0–39. Missing data earns zero.

Say: “The AI cannot make a lead HOT. It only extracts evidence; this code awards
the points.”

### Workflow 04 — Notification Outbox Worker

Explain:

- The main pipeline first saves work in `outbox_jobs`.
- The worker safely claims one due job.
- Success becomes `SENT`.
- Temporary failure becomes `RETRY` with a later `available_at` time.
- Exhausted failure becomes `DEAD_LETTER`.

Say: “This protects the lead when Gmail or HubSpot is temporarily unavailable.”

### Workflow 05 — Dead Letter Replay

Show the `REPLAY_QUEUED` result. Explain that a person inspects the error first,
then requeues only the selected job. The action is audited.

### Workflow 20 — HubSpot CRM Sync Template

Show the disabled nodes without opening credentials. Explain that it prepares
contact upsert, company upsert, and HOT-deal creation, but remains disabled until
a developer test-account credential is configured in n8n. Clearly call this
step “implementation-ready but not live-tested.”

## 5. Recommended live tests

### Demo A — valid new lead

Use a fresh UUID and the synthetic Maya Santos fixture. Expected progression:

`CREATED → AI_PENDING → SCORING → WARM/HOT → CRM_SYNC_PENDING`

Show the result fields: `submission_record_id`, `correlation_id`, score,
qualification, and `audit_event_id`.

### Demo B — idempotent repeat

Send the exact same UUID and payload again. Expect `IDEMPOTENT_REPEAT`,
`record_created: false`, and `should_continue: false`.

### Demo C — submission conflict

Keep the UUID but change the message or consent. Expect
`SUBMISSION_ID_CONFLICT` and `REVIEW_REQUIRED`.

### Demo D — invalid lead

Use an invalid UUID or `consent: false`. Expect an error outcome and no AI/CRM
processing.

### Demo E — recoverable failure

Show a synthetic outbox job that becomes `DEAD_LETTER`, then run Workflow 05.
Expect `REPLAY_QUEUED` and status `PENDING`.

## 6. PostgreSQL evidence to show

In the Terminal, query only synthetic rows. Useful tables are:

- `lead_crm.lead_submissions` — status, score, qualification, AI output.
- `lead_crm.audit_events` — chronological evidence of each decision.
- `lead_crm.review_queue` — cases waiting for a person.
- `lead_crm.outbox_jobs` — pending, retrying, sent, or dead-letter work.
- `lead_crm.crm_sync_records` — local-to-HubSpot object mapping.

Explain the difference between identifiers:

- `submission_id` comes from the source and enforces idempotency.
- `submission_record_id` is PostgreSQL’s internal row ID.
- `correlation_id` follows one processing attempt through audit events.

## 7. What not to claim in the video

Do not say Gmail or HubSpot is verified unless you personally configure the test
credentials and complete the account test checklist. Do not call the workflows
production-ready while they are inactive and tested only with synthetic data.

Accurate wording is: “The local pipeline and reliability controls are tested.
The Gmail and HubSpot adapters are safely prepared for credentialed test-account
validation.”

## 8. Suggested closing narration

“This project demonstrates more than a happy-path automation. It validates
untrusted input, prevents duplicates, constrains AI output, keeps scoring
deterministic, preserves an audit trail, and recovers external jobs through
retries and replay. The remaining account-specific step is to connect test-only
Gmail and HubSpot credentials in n8n and verify those adapters before activation.”
