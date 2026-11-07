# Booking capability spike — GHL reference

The supplied GHL page leads to [AutoFlow2xx consultation](https://go.aimdna.ai/widget/bookings/autoflow2xx-consultation). Browser observation verified the title, 30-minute duration, date/time selection and Asia/Manila default. The new form embeds that existing calendar and provides a normal link fallback. No appointment or account setting was changed.

The user's GHL reference replaces the earlier default HubSpot Meetings provider choice. HubSpot remains the CRM destination; booking evidence comes from GHL.

[HighLevel's current webhook guide](https://marketplace.gohighlevel.com/docs/webhook/WebhookIntegrationGuide/) specifies Ed25519 `X-GHL-Signature`. The callback verifies original bytes with the pinned public key before durable inbox insertion. It queues a canonical read; a browser success callback cannot confirm an appointment. [Get Appointment](https://marketplace.gohighlevel.com/docs/ghl/calendars/get-appointment/index.html) supports sub-account OAuth or Private Integration access with `calendars/events.readonly` and returns dates and status. Optional contact email matching additionally needs `contacts.readonly`.

| Capability | Status |
|---|---|
| Existing calendar loads and provides availability | Browser verified |
| Duration and default timezone | 30 minutes; Asia/Manila |
| GHL location/calendar IDs and server read credential | Unconfigured |
| Signed marketplace webhook subscription | Unconfigured |
| Create/cancel/reschedule live journey | Pending owner-controlled test identity and inbox |
| DST, stale/duplicate updates, ambiguous linkage | Synthetic PostgreSQL tests passed |
| Automatic HubSpot scheduled-stage updates | Disabled unless explicitly configured |

The server normalizes `dateUpdated` as the comparable provider version, re-reads canonical appointment state, stores UTC plus IANA timezone, and keeps unmatched/ambiguous linkage visible. If deletion cannot be verified by a server read, the item goes to review. Reconciliation exposes a saved cursor with a five-minute overlap; an operator must provide and verify the account's supported listing strategy before enabling polling.

Confirmed-booking production readiness remains blocked by the missing GHL server evidence configuration. The widget stays usable. Synthetic tests do not satisfy the credentialed booking gate.


Live follow-up: the approved read-only private integration authenticated calendar, event and contact reads. The actual application reader verified one controlled create/reschedule/cancel journey. The appointment is cancelled. The observed appointment response envelope prompted a test-first reader correction; legacy event envelopes remain supported. The public widget required marketing consent, so this controlled test used the admin appointment manager. The credential appeared in an accessible modal heading in a tool result and requires owner rotation before production activation. A signed live subscription remains unconfigured. See verification/live-accounts.md for complete evidence and limits.
