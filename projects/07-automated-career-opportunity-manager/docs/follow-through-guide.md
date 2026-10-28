# CareerFlow follow-through

Open http://127.0.0.1:8087 and sign in with your existing workspace password.

## Daily use

1. Start with **Today → Needs your response**. Each detected request keeps its source evidence. Unmatched messages stay visible; use **Review matching email** to connect the right application. Mark complete after handling it.
2. **Waiting on employer** tracks requests answered in captured Sent mail when reply headers and response text support the connection. A generic acknowledgement does not complete a task. You can correct tasks manually.
3. Use **Applications** for company/role/description search, submission-date filtering, full email text and linked actions. Saved opportunities are distinct from submitted applications.
4. Use **Quick capture** when no confirmation email arrives. Save the company, role, job URL and description, and explicitly choose whether you applied. For browser capture, open `/capture.html` and drag its bookmark to your bookmarks bar.
5. **Connections → Capture coverage** reports the successfully captured interval and errors. Import older messages in an interval of up to 90 days. Historical capture does not authorize Gmail label changes outside the existing seven-day window.

## Interviews and alerts

An availability request creates a task, not an appointment. A single explicit future range with a supported timezone can create a private tentative or confirmed Google Calendar reminder. Reschedules update that reminder; cancellation keeps its identity. No guests are added automatically. Ambiguous dates, missing end times, multiple options and conflicts need review.

The Windows helper polls every 20 seconds and starts at Windows sign-in. Docker and the computer must stay running and awake; the browser can close. Connections shows devices and alert delivery states; read, snooze or retry failed/uncertain delivery there. Focus Assist may hide notifications. “Delivered” means Windows accepted the display request, not that you read it.

To pair a Windows device, create a temporary code in Connections and run the displayed PowerShell command from this project directory. Tokens are scoped to notifications, encrypted with Windows DPAPI, and expire after 90 days. Exit through the tray menu. Remove the **CareerFlow desktop alerts** shortcut from your per-user Startup folder to disable startup. Device revocation is available through the notifications command API.

## Assistant

Try **“What needs my response?”**, **“How many applications?”**, **“Find PSB”**, or **“When am I available on 2026-11-02?”** (replace the date). Task/count answers use database facts even if Ollama is unavailable. Availability uses the recently imported primary calendar, within its coverage window, and suggests 30-minute slots during 9 AM–5 PM Manila weekdays.

Search evidence is ranked across stored applications, tasks and messages before being bounded for the local model. Answers show source links and coverage limits. Drafts and proposed edits/bookings remain editable previews; confirm them before execution. The model cannot directly send messages or change records.

## Limits and recovery

- Gmail capture runs every five minutes, one page of up to 100 messages per run, with a 24-hour overlap. Large mailboxes take several runs. “Catching up” is expected until the fixed window is exhausted.
- This is received-time capture, not a full Gmail history mirror. Older mail imported into Gmail requires a historical read; drafts, spam and trash are excluded.
- Matching uses reference/thread evidence and verified contact plus role. Company name alone never merges applications. Review uncertain matches.
- Extraction is conservative and English-focused. Inspect the linked email before responding or relying on a meeting time. No hiring-probability scores are invented.
- Service/network errors are separate from incorrect passwords. The Docker proxy re-resolves service addresses after container restarts. Retry connection once Docker is healthy.

## Verification boundary

Synthetic checks cover replay, lost leases, sent replies, corrections, unmatched requests, pairing, retries, calendar conflict/revision guards and scheduling lifecycle. Database fixtures roll back and do not contact employers. Live checks capture Gmail and read Calendar; no employer reply or guest invitation is used as a test.
