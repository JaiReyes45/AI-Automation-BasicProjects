# Testing and evidence

## Current public evidence

- [Workflow canvas](../screenshots/workflow-v1.png)
- [AI classification](../screenshots/ai-classification.png)
- [Confidence guardrail](../screenshots/confidence-guardrail.png)
- [PostgreSQL result](../screenshots/postres-results.png)

These files show the workflow was built and exercised visually. They do not
provide a dated, repeatable controlled-test record.

## Suggested checks

| Test | Expected outcome |
| --- | --- |
| Valid high-confidence expense | Classified result is normalized and persisted. |
| Valid low-confidence expense | Status becomes `needs_review`. |
| Missing required field | Validation stops the request before model use. |
| Invalid amount/date | Input is rejected or routed to a defined error result. |
| Repeated request | Document whether a duplicate database record is created. |
| Database unavailable | Record the visible failure and recovery behavior. |

Record actual execution IDs, payloads without private data, and observed
database results before marking any row verified.
