# Lead Intake Contract — V1

## Purpose

This document defines the JSON payload accepted by the Lead-to-CRM webhook. All portfolio testing uses synthetic data only.

## Endpoint role

The future n8n webhook receives one prospective-customer lead per request. It does not accept CRM updates, deal-stage changes, or bulk imports in V1.

## Required JSON fields

| Field | Type | Rule | Purpose |
|---|---|---|---|
| `submission_id` | UUID string | Required; unique for every browser submission | Idempotency key |
| `submitted_at` | ISO 8601 timestamp | Required; supplied by the client | Original submission time |
| `first_name` | string | Required; 1–100 characters after trimming | Contact identity |
| `last_name` | string | Required; 1–100 characters after trimming | Contact identity |
| `email` | string | Required; syntactically valid email after normalization | Primary duplicate key and contact method |
| `company_name` | string | Required; 1–150 characters after trimming | Company association |
| `message` | string | Required; 20–2,000 characters after trimming | AI extraction input |
| `consent` | boolean | Must be `true` | Permission to process the enquiry |
| `source` | string | One of `website_form`, `demo_form`, `test_client` | Attribution and auditability |

## Optional JSON fields

| Field | Type | Rule | Purpose |
|---|---|---|---|
| `job_title` | string | Maximum 150 characters | Decision-maker context |
| `company_size` | integer | Positive integer when supplied | Lead-scoring input |
| `website` | string | Valid URL when supplied | Company context |
| `phone` | string | Store as supplied; no V1 verification | Optional contact method |
| `country_code` | string | ISO 3166-1 alpha-2 when supplied | Service eligibility input |
| `budget_currency` | string | ISO 4217 code when supplied | Budget context |
| `budget_amount` | number | Zero or positive when supplied | Lead-scoring input |

## Example synthetic payload

```json
{
  "submission_id": "3f3f7df7-4d72-4d8b-bc09-294e4445f4c0",
  "submitted_at": "2026-09-21T10:00:00Z",
  "first_name": "Maya",
  "last_name": "Santos",
  "email": "maya.santos@example-business.test",
  "company_name": "Northstar Retail Systems",
  "job_title": "Operations Director",
  "company_size": 48,
  "website": "https://northstar-retail.example",
  "country_code": "PH",
  "budget_currency": "PHP",
  "budget_amount": 150000,
  "message": "We want to automate invoice processing and approval routing before the next quarter. I lead operations and would like to discuss an implementation plan.",
  "consent": true,
  "source": "test_client"
}
```

## V1 validation outcomes

- Missing or malformed required fields: `INVALID`
- `consent` is `false`: `INVALID`
- Reused `submission_id`: return the prior processing result; do not process again
- Existing normalized email with a new `submission_id`: record a new intake event and mark it for duplicate handling
- Valid submission: continue to AI fact extraction and deterministic scoring

## Explicit V1 exclusions

- File uploads
- Anonymous submissions
- Bulk lead imports
- CRM-originated updates
- Live production personal data
