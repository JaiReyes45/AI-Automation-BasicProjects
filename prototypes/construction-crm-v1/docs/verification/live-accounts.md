# Live account verification —7 November2026

HubSpot portalREDACTED_PORTAL_ID and the AutoFlow2xx GHL sub-account were tested with the owner's explicitly approved scopes and controlled identity. The owner separately approved a unique deal field, clearly labelled sandbox records, and one appointment's create/reschedule/cancel journey.

## HubSpot

The actual application adapter completed a controlled partial-save recovery, replayed one enquiry without creating new provider objects, and reused its contact/company for a second enquiry with a separate deal. Read-back confirmed actual object IDs, associations, the unique writable construction_submission_id property, and the Qualified To Buy unscheduled stage in the existing Sales Pipeline. The interruption was deliberately injected after a real association; it was not a measured provider outage. Qualification was a controlled HOT fixture, not a live model result.

Two deals are labelled Construction CRM TEST. They and the test company remain for owner review. Existing matching contact data was reused without rewriting its details. Actual returned IDs and checks are in live-account-report.json. Automatic scheduled-stage updates remain disabled.

## GHL

The calendar and contact/event read APIs authenticated successfully. One owner-approved appointment was created for9 November2026 at4:30pm Manila time, rescheduled to4:00pm, and cancelled. Separate authenticated reads through the actual application reader confirmed each state. The final canonical read confirms cancelled; no active test reservation is claimed.

Captured real provider responses were then replayed through the actual PostgreSQL store. Identity matched, all three states projected, an older response could not rewind cancellation, UTC/IANA storage was correct, and CRM failure remained independent. This replay is distinguished from the live API observations.

The live response used an appointment envelope, while the initial reader expected event. A regression failed first, then the reader was corrected to accept the actual envelope while preserving source validation. A separate database regression covers a newer changed time when a provider omits a reschedule flag. Full-suite evidence is recorded separately.

The public widget required a marketing-consent checkbox. It was left unchecked; the controlled appointment used the owner's admin appointment manager. The admin picker lacked Asia/Manila, so UTC+8 Asia/Kuala_Lumpur was used for this test only; canonical reads confirmed the intended instants and application storage retains Asia/Manila. Global account and contact timezone settings were not changed. Public customer consent/booking acceptance is still an owner-review item.

## Security and deployment boundary

Both approved keys were stored using Windows user encryption outside the synced checkout. The GHL modal exposed its token inside an accessible heading in a tool result. The clipboard was cleared, and no token is included in these reports or the source package. The owner must rotate this read-only GHL token through the account UI before production activation. Credential rotation requires a human handoff under the computer-use policy.

The HubSpot account gate passed. The GHL journey passed, but its release gate stays pending until credential rotation. No production worker, signed webhook subscription, public deployment or repository publication was activated. The always-on extraction model and full owner accessibility/release journeys remain pending. The screenshot API timed out, so no portable browser screenshot is claimed; authenticated provider IDs and versioned evidence remain available.
