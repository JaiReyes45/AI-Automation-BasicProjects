# Catalog, pricing and qualification

All amounts below are fictional PHP portfolio examples from the original catalog as represented in [004](../database/004_catalog_completion.sql). Read actual active, approved database rows at runtime; this table must not override operator edits.

| Original service | PHP range / unit |
|---|---|
| Initial 20-minute consultation | Free |
| Detailed discovery session | 1,500 / session |
| Existing workflow audit | 3,000–6,000 |
| Written process map and proposal | 2,500–5,000 |
| Simple single workflow | 6,000–12,000 |
| Intermediate automation | 15,000–30,000 |
| Advanced multi-workflow system | 35,000–70,000 |
| Additional standard integration | 3,000–7,500 |
| Custom API integration | 8,000–20,000 |
| Workflow repair | 3,000–10,000 |
| Basic CRM data-entry automation | 10,000–18,000 |
| Lead intake and deduplication | 18,000–30,000 |
| Complete lead-to-CRM automation | 30,000–55,000 |
| CRM cleanup or field mapping | 8,000–20,000 |
| CRM-to-email notification workflow | 8,000–15,000 |
| Basic rule-based FAQ bot | 8,000–15,000 |
| Telegram AI FAQ assistant | 15,000–25,000 |
| AI knowledge-base chatbot | 25,000–45,000 |
| AI customer support with human handoff | 40,000–70,000 |
| AI chatbot with CRM integration | 50,000–85,000 |
| Additional messaging channel | 10,000–25,000 |
| Basic maintenance | 4,000 / month |
| Standard maintenance | 7,500 / month |
| Priority monitoring and maintenance | 12,000 / month |
| Additional out-of-scope work | 900–1,500 / hour |

All unmarked amounts are one-time service prices. Hourly totals need agreed hours; monthly fees remain separate. Scope and response/delivery commitments require review.

| Informational package | Starting at PHP | Original inclusions, abbreviated |
|---|---:|---|
| Starter Automation | 7,500 | One workflow, two apps, basic conditions, error notification, one revision, 7 support days |
| Business Workflow | 18,000 | Three apps, multiple steps, validation/transforms, error handling, basic audit, two revisions, 14 support days |
| AI Assistant | 30,000 | One channel, approved knowledge, natural-language responses, persistence, confidence checks, escalation, two revisions, 14 support days |
| CRM Automation | 35,000 | Intake, validation, deduplication, CRM sync, qualification, error handling, audit, two revisions, 14 support days |

Packages are informational only, including `/rates`. Never calculate a package total, treat a starting price as a fixed quote, or invent an upper bound. Support days are not delivery promises. Persistence does not automatically include PostgreSQL, and basic audit history does not include a dashboard.

| Original adjustment | PHP / rule |
|---|---|
| Additional standard application | 3,000–7,500 |
| Custom API | 8,000–20,000 |
| AI feature | 8,000–15,000 |
| PostgreSQL database | 8,000–15,000 |
| Human-handoff system | 8,000–15,000 |
| Dashboard or analytics | 8,000–20,000 |
| Delivery under seven days | 25%; feasibility and calculation basis require review |
| Additional revision | 1,500–3,000 |
| Data migration | Human quotation |
| Discount | Human approval |

## Automatic estimates

[005](../database/005_service_estimate_policy.sql) records the latest approved strategy. After discovery and explicit `/confirm`, choose a supported service range, add only eligible approved adjustments, and save `service_code` plus the calculation breakdown. Confirmation enables a preliminary estimate; it is not purchase or delivery acceptance.

| Route | Current configured scope limit | Base PHP range |
|---|---|---:|
| `workflow_simple` | Explicit `basic` workflow, up to 2 canonical distinct apps | 6,000–12,000 |
| `workflow_intermediate` | `multi_step` with up to 3 apps, or `basic` with exactly 3 apps | 15,000–30,000 |
| `crm_data_entry` | Narrow standard email-to-CRM entry, up to 2 apps | 10,000–18,000 |
| `telegram_faq_ai` | Telegram plus explicit FAQ scope, up to 1 app; AI included; non-FAQ goes to review | 15,000–25,000 |

The revised engine uses explicit workflow complexity as well as category and canonical application count; complex or unknown scope cannot automatically select a workflow rate. Two-app `multi_step` selection of the PHP 15,000 intermediate minimum, Telegram FAQ PHP 15,000–25,000, and non-FAQ handoff passed unit tests. Narrow CRM also requires explicit source/destination direction, supported email and CRM applications, and a create/update operation; reverse-direction rejection passed unit testing. Broader CRM, migration, multi-workflow, custom or ambiguous scope requires review. Remaining provider/Telegram-only scope cases require the specific coverage recorded in the test matrix.

Confidence below 0.75, missing/invalid rates, human-review flags, under-seven-day delivery, or a total upper bound above PHP 85,000 prevent automatic estimates. Preserve conservative review flags. Do not double-charge included features or silently add uncertain inclusions. Service price changes must flow from the database, never model instructions.

Example after verified narrow CRM discovery: Gmail to HubSpot, no optional features, 14-day requested timeline, `/confirm` → preliminary PHP 10,000–18,000. The narrow CRM range passed the engine unit test; real local Ollama CRM discovery passed the native subworkflow smoke test. This does not establish a live Telegram estimate/delivery.

Every estimate must include:

> This is a preliminary, non-binding estimate based on the information currently available. The final quotation will be confirmed after reviewing the complete workflow requirements, integrations, and access requirements.

Third-party subscriptions, hosting, domains, AI usage, paid APIs, premium CRM features and messaging charges are excluded unless explicitly listed.

## Approved qualification

The user approved weights: service fit 20, project clarity 20, budget fit 20, timeline 10, decision authority 10, urgency 5, contact completeness 15. Total is capped at 100; cold 0–44, warm 45–74, hot 75–100. Consent and contact are prerequisites. Hot leads request high-priority human review; the model never assigns the final score.

Current engine evidence checks include problem/apps for clarity, budget at least the estimate upper bound, timeline at least seven days, explicit decision-maker status, and timeline within 30 days for urgency. The approved 100-point hot-lead case passed unit testing, and approved/unapproved persistence passed SQL assertions. Full scoring-band boundaries and remaining provisional evidence mappings still need verification.

Teaching note: service ranges express uncertainty honestly. Package advertising, deterministic estimate arithmetic, qualification and a human final quotation are separate decisions.

## Runtime-policy alignment

[006](../database/006_runtime_policy_alignment.sql) is being applied; successful completion is not yet recorded here. It documents the correct 24 required extraction fields, including `workflow_complexity`, and existing scope/scoring predicates. These are conservative implementation defaults, not newly approved business rules. Metadata edits do not reconfigure the validator or grant new scope approval; approved prices, routes, weights and approval flags are preserved.

The revised hot-lead logic preserves an existing handoff reason (such as `consultation_requested`) and raises its priority to `high`; the regression passes. App correction plus a PostgreSQL addition is preserved across turns and yields PHP 14,000–27,000 in the unit scenario. Commercial/sensitive checks still take precedence. Final revised engine deployment confirmation is pending; source-test PASS does not prove these latest changes are live.
