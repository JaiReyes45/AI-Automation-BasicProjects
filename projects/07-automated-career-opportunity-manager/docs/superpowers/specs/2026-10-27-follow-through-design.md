# CareerFlow follow-through — approved direction

User approval: October 27, 2026, “Now implement these changes”, following the six-milestone proposal. Windows desktop notifications selected; local computer and Docker must stay awake.

## Outcome
An employer asking for availability must surface with application context, an evidence-linked response task and a desktop alert. Explicit proposed interview times become private tentative holds; confirmed/rescheduled/cancelled appointments retain one identity. Missing identity or time never makes an actionable email disappear or fabricates certainty.

## Architecture and constraints
Keep Flutter web, Python, PostgreSQL, n8n and local Ollama. Extend existing immutable action previews and optimistic versions. No employer reply/invitation is sent without deliberate review. Automatic calendar holds are private, contain no guests, and do not imply acceptance. Existing data and Docker volumes are preserved.

Use durable mailbox synchronization state with resumable pagination and bounded backfill. Distinguish capture coverage from Gmail label authorization: historical import does not authorize old-mail label mutation. Saved opportunities, user-confirmed submissions and email-confirmed submissions remain distinct.

Tasks are separate from hiring stage and may exist without a matched application. Keep source message, actor, explicit deadline, request type, evidence and correction history. Notifications use a durable deduplicated queue with leases/retry and acknowledgment. A scoped paired Windows helper polls local notification delivery independently of the browser.

Today prioritizes needs-response, upcoming interviews, waiting-on-employer and recent automation. Application details combine source email, tasks and scheduling. Assistant retrieval includes relevant tasks and unresolved messages with source references; Ollama summarizes evidence and drafts, never executes.

## Approach
Selected: extend the existing local stack in vertical milestones. Replacing the app with a comparable open-source tracker would lose existing integration and does not establish complete capture. A visual-only redesign leaves the main failure unchanged. An email-only tracker cannot prove submissions with no email; provide quick capture and a browser helper with explicit applied confirmation.

## Acceptance
1. Relevant new-thread availability requests without keyword subjects are captured; interrupted synchronization resumes without duplicates and reports coverage truthfully.
2. Reference/thread matches retain priority. New-thread evidence can suggest/link a unique application; company alone never merges two roles. Unmatched interview requests remain urgent.
3. Replay creates one task/alert; stale quoted requests do not reopen completed work. No explicit deadline means no invented deadline.
4. Windows helper delivers alerts with the tab closed; failed/uncertain delivery is visible; completion suppresses stale reminders.
5. Calendar state distinguishes request/proposal/tentative/confirmed/cancelled from queued/synced/failed. Reschedules preserve event identity; ambiguous times require review.
6. Today and assistant agree on actionable records and disclose data coverage. Existing search/profile/document workflows still work at mobile and desktop widths.

## Verification boundaries
Use synthetic end-to-end fixtures and rollback-only integration tests before deployment. Do not send real employer emails or invitations as tests. A genuine PSB match cannot be asserted without examining its evidence. Local uptime limits remain visible.
