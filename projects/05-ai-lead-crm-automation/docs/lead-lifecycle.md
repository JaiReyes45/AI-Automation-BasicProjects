# Lead Lifecycle — V1

## Purpose

This document defines the operational states a lead submission can occupy during processing. These states support auditability and error recovery; they are separate from HubSpot sales pipeline stages.

## Processing states

| State | Meaning | Next allowed state |
|---|---|---|
| `RECEIVED` | Webhook accepted the raw submission and created an intake record. | `VALIDATING` |
| `VALIDATING` | Required fields and business validation rules are being checked. | `INVALID`, `DUPLICATE`, `AI_PENDING` |
| `INVALID` | The submission failed validation and will not be sent to the CRM. | Final |
| `DUPLICATE` | A new submission matched an existing person or was an idempotent repeat. | `REVIEW_REQUIRED` or final idempotent response |
| `AI_PENDING` | A valid lead awaits structured AI fact extraction. | `ANALYZING` |
| `ANALYZING` | The system is extracting structured facts from the message. | `SCORING`, `REVIEW_REQUIRED` |
| `SCORING` | Deterministic rules calculate a score and qualification band. | `QUALIFIED_HOT`, `QUALIFIED_WARM`, `QUALIFIED_COLD` |
| `QUALIFIED_HOT` | The lead meets the HOT score threshold and eligibility rules. | `CRM_SYNC_PENDING` |
| `QUALIFIED_WARM` | The lead is valid but not ready for immediate sales escalation. | `CRM_SYNC_PENDING` |
| `QUALIFIED_COLD` | The lead is valid but has low current fit or urgency. | `CRM_SYNC_PENDING` |
| `CRM_SYNC_PENDING` | The lead is ready to create or update CRM records. | `CRM_SYNCED`, `SYNC_FAILED` |
| `CRM_SYNCED` | Required CRM records were created or updated successfully. | `ROUTED`, `FOLLOW_UP_PENDING`, final |
| `ROUTED` | A HOT lead was sent to the sales-routing destination. | Final |
| `FOLLOW_UP_PENDING` | A permitted follow-up action is waiting to be created or reviewed. | `FOLLOW_UP_SENT`, `REVIEW_REQUIRED` |
| `FOLLOW_UP_SENT` | The follow-up action was successfully recorded or sent. | Final |
| `SYNC_FAILED` | CRM synchronization exhausted its retry policy or returned a non-retryable error. | `CRM_SYNC_PENDING`, `REVIEW_REQUIRED` |
| `REVIEW_REQUIRED` | A person must resolve an ambiguity, conflict, or unrecoverable failure. | A valid next state chosen after review |

## Important distinctions

- `INVALID` means the input does not meet the contract.
- `DUPLICATE` means the input may be valid, but requires idempotency handling or duplicate review.
- `REVIEW_REQUIRED` preserves the lead and its evidence; it is not a rejection.
- `SYNC_FAILED` does not erase a valid, qualified lead.
- A lead score is not a CRM pipeline stage.

## V1 routing policy

| Qualification | CRM action | Human action |
|---|---|---|
| HOT | Create or update contact and company; create a deal when eligible | Notify the sales owner |
| WARM | Create or update contact and company | Add to a manual nurture/review queue |
| COLD | Create or update contact and company when valid | No automated sales escalation |
| INVALID | Do not sync to CRM | Retain a minimal audit record only |
| REVIEW_REQUIRED | Do not continue automatically | Reviewer resolves and restarts from the appropriate state |

## V1 terminal states

`INVALID`, `ROUTED`, `FOLLOW_UP_SENT`, and a successfully handled idempotent repeat are terminal for an individual workflow execution. The underlying lead record may receive a later, new submission.
