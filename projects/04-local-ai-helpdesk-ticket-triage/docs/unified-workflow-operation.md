# Running Workflow 09: Unified Helpdesk Operations

This guide is for a disposable local demo environment. Do not activate the
current protected project environment. Workflow 09 is imported inactive by
design.

## 1. Confirm prerequisites

1. Start the disposable Compose stack and verify it is healthy:

~~~bash
docker compose config --quiet
docker compose up -d
docker compose ps
~~~

2. Apply migrations 001 through 006 in sequence.
3. Confirm Ollama has the llama3.2:3b model and Mailpit is reachable at
   localhost port 8025.
4. Create or verify these n8n credentials in the disposable instance:

   - Helpdesk PostgreSQL (helpdesk_app)
   - Mailpit SMTP (local)

Never place credential values in workflow JSON or shell commands.

## 2. Import the required workflows

1. Import workflow 09:

~~~bash
docker compose exec -T n8n n8n import:workflow \
  --input=/projects/04-local-ai-helpdesk-ticket-triage/workflows/09-unified-helpdesk-operations.json
~~~

2. Also keep workflows 02 and 03 imported but inactive. The failed-job replay
branch in workflow 09 retains their stable IDs for bounded replay execution.
3. Keep original workflows 01, 04, 05, 06, 07, and 08 inactive. Workflow 09
contains their trigger paths, so activating originals too would duplicate
webhooks or scheduled workers.
4. Verify the state:

~~~bash
docker compose exec -T n8n n8n list:workflow --active=false
docker compose exec -T n8n n8n list:workflow --active=true
~~~

## 3. Inspect the unified canvas

Open workflow 09 in the disposable n8n UI. Read the eight colored sections
from left to right and top to bottom:

1. Intake and validation
2. AI classification
3. Routing, SLA, and persistence
4. Notification worker
5. Human review
6. Error capture / dead-letter handling
7. Failed-job reprocessing
8. SLA-breach monitoring

Confirm all PostgreSQL nodes use Helpdesk PostgreSQL (helpdesk_app), all email
nodes use Mailpit SMTP (local), and the workflow remains unpublished.

## 4. Activate for a controlled demo

Activating workflow 09 activates its intake, review, reprocessing, notification,
and SLA-monitor triggers together. Do this only in the disposable instance.

1. Record the current active-workflow list.
2. Activate workflow 09 in the UI.
3. Confirm the active-workflow list contains workflow 09 only for Helpdesk.
4. Do not activate workflows 01 or 04 through 08 separately.

## 5. Test the normal intake path

Submit a synthetic request:

~~~bash
curl --fail-with-body -X POST http://127.0.0.1:5678/webhook/helpdesk/tickets \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: unified-demo-001' \
  --data '{"email":"alex@example.test","subject":"Cannot sign in","description":"Password reset did not restore access."}'
~~~

Expected result:

- A safe 202 response with a correlation ID
- One durable ticket and one ticket-accepted event
- Valid Ollama classification, deterministic route, SLA deadline, and routing event
- One notification-outbox row and an acknowledgement visible in Mailpit

Repeat the exact request. Verify there is still one ticket and one outbox item
for that idempotency key.

## 6. Test review, failure, and replay

1. Send a synthetic account-takeover ticket. Confirm P1/security routing and a
   review task.
2. Resolve the review task through the review webhook with a synthetic reviewer
   identity and an allowed queue.
3. For SMTP recovery, stop Mailpit only in the disposable environment, allow
   three notification attempts, restore Mailpit, then call the reprocessing
   webhook with the failed-job ID.
4. Confirm the existing outbox row is reset; no duplicate ticket or outbox key
   may be created.

## 7. Test SLA monitoring

1. Give a synthetic routed ticket a past SLA deadline in the disposable
   database.
2. Wait for the five-minute monitor or run the monitor path manually.
3. Confirm one breach record, one breach event, one escalation outbox item, and
   one Mailpit escalation message.
4. Repeat the monitor run. Counts must not increase.

## 8. Shut down safely

1. Deactivate workflow 09.
2. Confirm no Helpdesk workflow is active.
3. Stop the disposable stack:

~~~bash
docker compose stop
~~~

Do not use docker compose down -v unless deletion of disposable volumes is
explicitly intended.
