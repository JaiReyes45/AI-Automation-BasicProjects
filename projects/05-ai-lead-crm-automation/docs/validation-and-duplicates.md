# Validation and Duplicate-Handling Policy — V1

## Processing order

1. Receive the JSON payload.
2. Persist a minimal intake/audit record.
3. Validate payload structure, required values, and consent.
4. Apply idempotency handling using `submission_id`.
5. Check person-level duplicates using normalized email.
6. Continue only valid, non-idempotent submissions to AI extraction and scoring.

## Validation rules

| Rule | Failure outcome | CRM action |
|---|---|---|
| Request body is not valid JSON | Reject request with a clear validation response | None |
| Required field is missing, empty, or exceeds its defined length | `INVALID` | None |
| `submission_id` is not a UUID | `INVALID` | None |
| `submitted_at` is not a valid ISO 8601 timestamp | `INVALID` | None |
| Email is not syntactically valid after trimming and lowercasing | `INVALID` | None |
| `message` is shorter than 20 or longer than 2,000 characters | `INVALID` | None |
| `consent` is not `true` | `INVALID` | None |
| `source` is outside the allowed V1 values | `INVALID` | None |
| Optional numeric fields are invalid or negative | `INVALID` | None |
| `website` is supplied but is not a valid URL | `INVALID` | None |

## Normalization rules

Before comparison or storage:

- Trim leading and trailing whitespace from text values.
- Convert email addresses to lowercase.
- Preserve the original submitted email separately for audit display when needed.
- Convert `country_code` and `budget_currency` to uppercase.
- Do not alter the raw message; preserve it as submitted.
- Store the normalized payload separately from the raw payload.

## Idempotency policy

`submission_id` identifies one client submission attempt.

| Situation | Result |
|---|---|
| New `submission_id` | Create and process a new intake event. |
| Existing `submission_id` with the same normalized payload hash | Return the original recorded result; do not repeat AI, CRM, or follow-up actions. |
| Existing `submission_id` with a different normalized payload hash | Flag `REVIEW_REQUIRED`; this indicates a client or integration defect. |

The system must enforce uniqueness at the database level. An n8n-only check is insufficient because retrying executions may run concurrently.

## Person-level duplicate policy

A person-level duplicate is different from an idempotent repeat. It occurs when a new `submission_id` uses an email already associated with an earlier lead.

| Situation | Result |
|---|---|
| New email | Continue normally. |
| Same normalized email, same company, materially similar message within 30 days | Mark as `DUPLICATE`; link the new intake event to the existing lead. |
| Same normalized email, but new/different company or materially different request | Mark `REVIEW_REQUIRED`; preserve both records. |
| Same email found in HubSpot but not in PostgreSQL | Do not create a second contact; use the CRM upsert/update path after review or a controlled match. |

## Manual-review triggers

- Duplicate conflict involving company identity or materially changed information
- Reused `submission_id` with a different payload
- Invalid or incomplete CRM match
- Country outside the Philippines
- AI output fails schema validation after its retry allowance
- External-system failure that exhausts retry limits
- Suspected spam or inappropriate content

## Privacy and audit requirements

- Use synthetic data in all screenshots, tests, and public workflow exports.
- Do not place raw lead content, email addresses, tokens, or credentials in public issue logs.
- Record timestamps, submission ID, normalized email hash or protected identifier, lifecycle state, score-rule version, integration attempt outcomes, and reviewer action.
- Retain only the minimum data needed to investigate invalid submissions in V1.
