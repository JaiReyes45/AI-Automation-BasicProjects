# Controlled Demo Runbook

Use this runbook only in a disposable local environment. Keep the existing
project environment protected: do not activate, publish, or alter its
workflows for a demo.

## 1. Prepare a disposable environment

1. Clone the repository into a new directory; do not reuse existing Docker
   volumes.
2. From the clone's repository root, run:

~~~bash
cp .env.example .env
docker compose config --quiet
docker compose up -d
docker compose ps
docker compose logs --tail=100 n8n
~~~

3. Replace every placeholder in .env with new local values. Generate a new
   n8n encryption key and new database passwords. Never copy or print values
   from another environment.
4. Confirm PostgreSQL, Ollama, and Mailpit are healthy. Keep n8n bound to
   127.0.0.1:5678 and Mailpit bound to 127.0.0.1:8025.

## 2. Provision the demo

1. Apply migrations 001_helpdesk.sql through 006_sla_breach_monitor.sql in
   order against the disposable database.
2. Create the disposable least-privilege helpdesk_app role with migration 002.
3. Create fresh local n8n credentials named Helpdesk PostgreSQL (helpdesk_app)
   and Mailpit SMTP (local). Do not export credentials or put passwords in JSON.
4. Import workflows 01 through 08. Confirm they are initially inactive:

~~~bash
docker compose exec -T n8n n8n list:workflow --active=false
~~~

5. Check workflow 01 invokes 02 and 03, workflow 04 is the notification
   worker, and workflow 08 is the SLA monitor.

## 3. Establish the baseline

~~~bash
node projects/04-local-ai-helpdesk-ticket-triage/tests/run-tests.js
node projects/04-local-ai-helpdesk-ticket-triage/tests/workflow-contracts.js
docker compose exec -T postgres sh -c \
  'exec psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < projects/04-local-ai-helpdesk-ticket-triage/tests/database-constraints.sql
~~~

The database test rolls back all synthetic rows. Record the start time and
baseline table counts using aggregates only.

## 4. Timed activation for the demo

1. Activate workflow 01 in the disposable n8n instance.
2. Activate workflow 04 only while testing acknowledgements.
3. Activate workflow 08 only while testing SLA escalation.
4. Leave workflows 02, 03, 05, 06, and 07 inactive; parent workflows invoke
   subworkflows and workflows 06/07 are support flows.
5. Never publish any workflow. Record which workflows are active before every
   test.

## 5. Run synthetic intake cases

Submit a happy-path ticket only to the disposable localhost endpoint:

~~~bash
curl --fail-with-body -X POST http://127.0.0.1:5678/webhook/helpdesk/tickets \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: demo-happy-001' \
  --data '{"email":"alex@example.test","subject":"Cannot sign in","description":"Password reset did not restore access."}'
~~~

Repeat that exact request. Expect safe 202 responses, exactly one ticket, and
one acknowledgement outbox item for its idempotency key.

Then run these synthetic cases individually:

| Case | Expected result |
|---|---|
| Invalid email or empty subject | Safe 400; no ticket. |
| Prompt-injection text | Treated as data; output satisfies contract. |
| Account takeover | Deterministic P1/security route and review task. |
| Low confidence or malformed model output | Capture or human-review outcome. |
| Duplicate request | One ticket and one outbox item. |

For each case, record correlation ID, status, classification validity, route,
SLA deadline, audit-event sequence, review status, and Mailpit message ID. Do
not capture full ticket descriptions.

## 6. Delivery, retry, and reprocessing

1. Confirm the normal acknowledgement in Mailpit at localhost port 8025.
2. In the disposable stack only, stop Mailpit:

~~~bash
docker compose stop mailpit
~~~

3. Let workflow 04 reach three delivery attempts. Confirm the outbox uses
   sending/failed states and workflow 06 records the exhausted failure.
4. Restore Mailpit:

~~~bash
docker compose up -d mailpit
~~~

5. Invoke workflow 07 with its failed-job ID. Confirm it resets the existing
   outbox item and does not create a duplicate ticket or notification key.
6. For classification recovery, stop Ollama in the disposable stack, submit a
   synthetic ticket, verify failure capture, restart Ollama, and reprocess.
   Record original and recovered idempotency/correlation IDs.

## 7. SLA monitor

1. Change only a synthetic routed ticket deadline to a past timestamp.
2. Run workflow 08 once manually or wait for its five-minute schedule.
3. Confirm one SLA-breach record, one audit event, and one SLA escalation
   outbox item.
4. Run the monitor again; all three counts must remain unchanged.
5. Confirm Mailpit shows the escalation subject, not an acknowledgement subject.

## 8. Evidence and cleanup

1. Record total cases, contract-valid rate, labelled-category agreement, review
   rate, duplicate result, latency, retry/recovery result, and SLA idempotency.
2. Retain only sanitized screenshots and aggregate query output.
3. Deactivate workflows 01, 04, and 08 and verify:

~~~bash
docker compose exec -T n8n n8n list:workflow --active=true
~~~

4. Stop the disposable environment:

~~~bash
docker compose stop
~~~

Never run docker compose down -v unless deletion of the disposable volumes is
explicitly intended.

## Abort rules

Stop immediately if a non-synthetic request, credential, or unexpected external
endpoint appears. Deactivate the affected workflow, stop disposable services,
preserve only necessary logs, and never copy database volumes or encrypted n8n
credential data into another environment.
