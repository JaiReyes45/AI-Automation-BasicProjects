# HubSpot capability spike — sandbox REDACTED_PORTAL_ID

Read-only browser evidence on 2026-11-07: authenticated portal **Project 05 - CRM Sandbox**. Connected Apps shows no connections. Legacy Apps are unavailable in this account. Service Keys shows **No Service Keys Created**. No credential was created or copied, and no API write was attempted.

Current service keys use Bearer authentication and object-scoped permissions: [official service-key documentation](https://developers.hubspot.com/docs/apps/developer-platform/build-apps/authentication/account-service-keys).

Required adapter scopes, to be reviewed at credential creation: `crm.objects.contacts.read/write`, `crm.objects.companies.read/write`, `crm.objects.deals.read/write`. Deal correlation also requires a reviewed, existing unique property; provisioning a property may require `crm.schemas.deals.write`. Meetings reads are a separate capability gate.

Adapter endpoints: `/crm/v3/objects/{contacts,companies,deals}`, their `/search` endpoints, and `/crm/v4/objects/{from}/{id}/associations/default/{to}/{id}`. Internal pipeline/stage IDs must be explicitly configured, not inferred from labels. The [contacts guide](https://developers.hubspot.com/docs/api-reference/legacy/crm/objects/contacts/guide) and [deals guide](https://developers.hubspot.com/docs/api-reference/legacy/crm/objects/deals/guide) describe these object operations.

| Capability | Evidence |
|---|---|
| Authenticated sandbox | Verified in browser |
| API scopes and returned object IDs | Unverified; no service key |
| Pipeline and unscheduled stage IDs | Unconfigured |
| Unique correlation property for deals | Unconfigured |
| Contact/company/deal associations | Adapter tests only |
| Live returning-contact and partial-failure journey | Pending credentialed sandbox test |

The adapter will preserve partial mappings, reconcile uncertain writes, and require a unique deal correlation property. Search alone does not prove a timed-out create did not happen. Unresolved effects enter review; no exactly-once claim is made. A HOT score never supplies the scheduled stage. The configured unscheduled stage must differ from any later booking-confirmed stage.


Live follow-up: the owner approved a six-scope service key and a dedicated unique deal property, construction_submission_id, created through the account UI without expanding key scopes. The actual adapter passed live sandbox contact/company/deal writes, association read-back, controlled interruption recovery, duplicate replay and returning-contact reuse. The two test deals are labelled Construction CRM TEST and remain in Qualified To Buy, an unscheduled stage in the default Sales Pipeline. See verification/live-accounts.md for returned IDs, limitations and current release status.
