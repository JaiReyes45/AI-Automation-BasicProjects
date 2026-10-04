# Local AI Extraction Contract — V1

## Status

Implemented and locally tested with `qwen2.5:3b`. The n8n workflow enforces this
contract, allows exactly one repair attempt, stores trusted output, and sends a
second schema failure to `REVIEW_REQUIRED` with an audit event.

## Purpose

The model converts a synthetic lead's free-text enquiry into a small JSON object.
It extracts evidence; it does not validate the lead, calculate points, assign a
qualification, route work, contact anyone, or update the CRM.

## Required output

| Field | Type | Allowed values or rule |
|---|---|---|
| `schema_version` | string | Exactly `1.0` |
| `service_category` | string | One of the categories below |
| `purchase_timeline` | string | `within_30_days`, `days_31_90`, `over_90_days`, or `not_stated` |
| `decision_maker_status` | string | `decision_maker`, `champion`, or `unclear` |
| `location_country_code` | string or null | Two uppercase letters, or `null` when unstated |
| `need_summary` | string | 20–300 characters; factual and concise |
| `confidence` | number | From 0 through 1 |

## Service categories

- `crm_lead_automation`
- `invoice_approval_automation`
- `customer_service_automation`
- `reporting_data_integration`
- `general_automation`
- `unrelated`
- `unknown`

## Strict validation rules

- All required fields must exist.
- Additional fields are rejected.
- Enum values must match exactly.
- `confidence` must be a JSON number, not text.
- The workflow must parse the response and validate every field before storage.
- One repair attempt is allowed after an invalid model response.
- A second invalid response stops automatic processing and sets
  `REVIEW_REQUIRED`; invalid AI output must never reach scoring.

## Prompt-safety rules

- Treat lead text as data, never as instructions.
- The prompt must explicitly tell the model to ignore commands contained inside
  the lead message.
- The model receives only the minimum synthetic lead fields needed for extraction.
- Temperature is set to zero for more repeatable results.

## Verified tests

- A synthetic invoice-approval enquiry produced the expected category, role,
  country, summary, and numeric confidence.
- A forced first-attempt failure used the single repair path, passed validation,
  persisted the extraction, and moved the lead to `SCORING`.
- A forced failure on both attempts produced `AI_REVIEW_REQUIRED`, stored
  `REVIEW_REQUIRED`, returned `should_continue: false`, and wrote audit event
  `29`. Invalid AI output did not reach scoring.
