# Final review fixes

One fresh whole-branch review found eleven Important issues and one role-control issue initially labeled Minor. The role issue was raised to Important because commissioning the requested trades is part of the intended product. All twelve entered one consolidated test-first fix pass; no second reviewer was dispatched.

| Finding | Result and regression evidence |
| --- | --- |
| Qualification health blocked worker startup | Actual service process answers its PostgreSQL-backed health route; unhealthy dependencies fail closed. |
| Dependent work remained queued | Owner acceptance and a successful repeated runtime check both wake eligible dependent tasks. |
| Exhausted delivery appeared pending | Final retry and final lease expiry publish failed CRM state and an owner-visible stopped event. |
| Provider review jobs were inaccessible | Linked owner review items expose a versioned, audited reconciliation retry; unknown intents still prevent duplicate creates. |
| Returning-contact enquiries detached old appointments | Existing canonical linkage survives another enquiry; conflicting identities enter ambiguity review. |
| Scheduled-stage policy was absent in production | Worker reads current verified integration policy; the disabled default remains explicit. |
| Booking-before-CRM missed scheduled-stage delivery | Confirmed deal mappings reconcile existing eligible appointments idempotently. |
| Cancellation raced with a stage write | Eligibility is rechecked after remote reads and after writes; an in-flight change enters review and preserves later manual stages. |
| Model discovery blocked saved projects | Project/evidence loading is independent of catalog success; only new commissions require an available model. |
| CRM completion stopped appointment observation | Receipt observation continues through terminal CRM/review states and later booking changes. |
| Receipt polling throttled itself and stopped on errors | Separate read budget, Retry-After, bounded backoff, cancellation and thirty-minute observation window with manual refresh. |
| Every runtime actor used the builder role | Explicit five-role commissioning control persists the chosen role without adding model sessions. |

Each reproducer was run failing before its fix, then passing. Final suites:91/91 local tests;19/19 PostgreSQL tests plus backup/restore. The20-lead hybrid pilot and actual published private n8n bridge were repeated after the fixes. Browser verification confirmed saved evidence during runtime failure and the Foreman selection.

The review did not establish live provider/model contracts, target-host image/TLS/network/secret configuration, owner accessibility acceptance, recovered-asset publication rights or capacity beyond the small V1 pilot. These remain documented release gates. Synthetic evidence never satisfies a live-account or owner gate.
