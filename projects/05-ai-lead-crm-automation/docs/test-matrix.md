# Controlled Synthetic Test Matrix

| Test | Expected result | Result |
|---|---|---|
| Core schema smoke test | Six core entities insert inside a rollback transaction | Passed |
| Core constraints | Duplicate email/submission, bad score, and orphan activity rejected | Passed |
| Valid webhook intake | `202`, `CREATED`, `AI_PENDING` | Passed |
| Invalid UUID | `422`, `INVALID_SUBMISSION_ID` | Passed |
| Missing consent | Persisted as `INVALID`; automation stops | Passed |
| Same ID and same payload | `IDEMPOTENT_REPEAT`; no duplicate row | Passed |
| Same ID and changed payload | `SUBMISSION_ID_CONFLICT`, `REVIEW_REQUIRED` | Passed |
| AI valid first/repair result | Strict schema accepted and stored | Passed |
| AI invalid on both attempts | `AI_REVIEW_REQUIRED`, attempt `2`, automation stops | Passed |
| Deterministic scoring | Stored breakdown, score, qualification, rule version | Passed |
| Outbox success | Job claimed once and marked `SENT` | Passed |
| Outbox exhausted failure | Job marked `DEAD_LETTER` | Passed |
| Dead-letter replay | Job reset to `PENDING`, attempts reset, audit written | Passed |
| Gmail adapter | OAuth credential and live test required | Unverified |
| HubSpot sync | Developer test-account credential and live test required | Unverified |
| Published end-to-end schedule | Intentionally not activated | Not performed |

All passed tests used synthetic records. SQL tests use `ROLLBACK` where possible.
