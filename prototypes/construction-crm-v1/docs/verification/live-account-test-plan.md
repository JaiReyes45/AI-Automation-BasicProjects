# Controlled live-account test

Approved so far: the HubSpot sandbox six CRM object scopes; GHL calendar/event/contact read-only scopes; encrypted local credential storage; owner-controlled test inbox supplied in this chat. Read-only API checks have succeeded. The owner subsequently explicitly approved all bounded writes below after an automatic-review rejection. These actions have now been executed; the appointment is cancelled. See live-accounts.md for evidence and the remaining credential-security gate.

Approved bounded writes:

1. In HubSpot portalREDACTED_PORTAL_ID, create one single-line Deal property named Construction submission ID, internal name construction_submission_id, with unique values. No API-key scope expansion is requested.
2. Use the supplied test inbox for an identifiable test contact. Reuse an existing matching contact without changing its details. Create/reuse one clearly named test company with reserved non-deliverable domain construction-crm-test.invalid, and at most two clearly labelled test deals in the existing Qualified To Buy stage. This stage does not assert a scheduled appointment. Test real returned IDs, associations, returning-contact reuse and duplicate replay. Preserve the labelled records and record their IDs for owner review.
3. On the AutoFlow2xx consultation calendar, book one free30-minute test appointment for Monday9 November2026 at4:30pm Asia/Manila if it remains available. Use the owner-controlled inbox provided in chat. Reschedule that same appointment to another available slot, then cancel it. This temporarily reserves calendar time and may send booking notifications. If a phone number is mandatory, stop rather than invent one.
4. Confirm each appointment state by an authenticated GHL API read, feed it through the actual appointment reader/store, and retain redacted evidence with provider IDs. A browser success screen alone does not satisfy booking confirmation.

These tests do not deploy a public service, publish a GitHub repository, activate a production worker, send marketing outreach, or expand the approved key scopes. The real extraction-model and complete owner usability gates remain separate.
