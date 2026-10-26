# CareerFlow workspace 1.1

## Find a specific application

Open Applications, enter a company, role or phrase from the saved job description, and choose Submission dates. A one-day range finds applications submitted on that day. The newest/oldest button changes ordering; unknown dates stay last. Dates come from the original linked confirmation in Manila time, or a manually entered submission date. Later employer updates do not move that date. Clear filters restores the full list.

The rounded journey cards on Overview open the chosen stage. Their numbers count current records; they are not hiring probabilities or a requirement to complete every intermediate stage. Assessment, offer, accepted and terminal outcomes remain available in the Applications stage filter.

Open a record and expand **Read received email**. Imported text includes the linked email conversation rather than a status summary. External images and HTML scripts are not loaded. Very long imports may be capped; **Open in Gmail** opens the complete original and attachments. Saved job descriptions can be added in Edit application; the application confirmation may not include the original job posting.

## Profile and documents

Use the avatar at the top right → View profile or Edit personal information. The Profile, Edit details and Documents tabs keep saved information, editing and requirements together. Save details when finished. Upload photo accepts PNG/JPG up to 4 MB and 16 megapixels; the local service normalizes it to a maximum 512-pixel JPEG and strips metadata. Uploading a photo saves immediately.

Profile and document storage remains in the project's private `local-data/profile` folder. A Drive link uses the account's existing sharing permissions; no school Drive OAuth connection is created.

## Interview calendar

Calendar imports the connected Google account's primary calendar every five minutes. It reads a rolling window of 30 days back to 180 days ahead, up to 2,000 events; exceeding the limit fails visibly instead of accepting an incomplete snapshot. The page displays Manila time and supports month navigation and day selection. Inspect the last-checked timestamp if data seems old.

Choose Plan an interview, select the application, enter Manila start/end times and optional guest email addresses, then review the complete preview. **Confirm meeting** queues the booking. Guests receive invitations when the worker creates it. Pending events are labeled queued; only a verified Google readback marks them synced. A recent sync is required, and known overlapping events block booking. Another calendar client can still create a conflicting event after the check.

## Local assistant and reviewed actions

Open Assistant. Search across application records, or select an application to include its linked email text. Examples: “Find QA internships,” “Draft a reply for this application,” or “Plan an interview on November 2 from 10:00 to 10:30.” Model output can be wrong; check the actual record and preview before proceeding.

Qwen3 4B runs in the project's private Ollama container, with no host API port. Its prompts stay on this device. Google operations still use Google APIs through n8n. The model context is bounded: up to roughly 10,000 characters of application records, two recent linked messages, 15 upcoming calendar events and four recent chat messages. This is not a full mailbox search. Use the main search/calendar screens for the complete imported data. Chat history currently lasts only while the Assistant screen remains open.

The assistant cannot execute actions. Review proposed action opens an editor; Review preview shows the immutable operation; only explicit confirmation can edit a record, send a reply or book a meeting. Reply recipients, subject/body and meeting guests/times are visible before confirmation. Confirmed edits run immediately; replies run every minute, meetings every five minutes while Docker is awake. Recent confirmed actions shows completion/failure. If a send outcome is uncertain, inspect Gmail Sent before composing again; automatic replay is disabled to avoid duplicates. Booking retries reuse a fixed event ID.

The first model load can take longer or time out; retry once the container finishes loading. A normal bounded count query was verified in under two seconds on the original RTX 4060 laptop. Timing varies with device load and prompt length.

## Enable on another installation

Run all commands from the repository root, after the standard local setup. The original installation already has these services and credentials configured.

```bash
docker compose --env-file projects/07-automated-career-opportunity-manager/.env -f projects/07-automated-career-opportunity-manager/compose.yaml --profile assistant up -d ollama
docker exec project07-automated-career-opportunity-manager-ollama-1 ollama pull qwen3:4b
```

The supplied assistant profile requests an NVIDIA GPU through Docker Desktop/WSL. Qwen's download is approximately 2.5 GB, with additional runtime memory required. On a CPU-only device remove that service's NVIDIA reservation deliberately and expect slower responses. Other CRM features work without starting the assistant profile. Preserve its named volume when updating.

In Google Cloud enable Calendar API in the same OAuth project. In n8n create a Google Calendar OAuth2 API credential with redirect `http://localhost:5678/rest/oauth2-credential/callback`, connect the intended account, and select it in every Google node in workflow 09. In workflow 08 choose the connected Gmail credential. Keep the internal service-header credential for CRM requests. Imported credential references identify the original installation, not a transferable Google session.

After checking the credentials, publish workflows 08 (one minute) and 09 (five minutes). Keep existing Gmail intake/reconciliation 06/07 published. CLI publication requires restarting only the project's n8n service. Never reimport exports to troubleshoot without preserving intentional editor changes; reimport can unpublish workflows.

References: [n8n Google OAuth setup](https://docs.n8n.io/integrations/builtin/credentials/google/oauth-single-service/), [Ollama Docker](https://docs.ollama.com/docker), [Qwen3 4B](https://ollama.com/library/qwen3:4b), [Calendar event creation](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert).

## Verification boundary

Google Calendar reading and empty action-worker runs were verified against the connected accounts. Reply formatting, immutable confirmation, account isolation, stale leases, uncertain sends and calendar conflicts were checked with synthetic tests. No live test email or invitation was sent. The first intentional real reply/booking should be checked in Gmail/Calendar; the original genuine employer follow-up progression check also remains open.
