# Edge cases and guardrails

| Scenario | Intended handling | Evidence in workflow |
| --- | --- | --- |
| Missing description, amount, or date | Do not continue to AI classification. | `Validate Expense` IF node. |
| Invalid amount or date | Treat as invalid input. | README documents deterministic validation. |
| Low confidence | Mark the expense `needs_review`. | Confidence branch and normalization node. |
| High confidence | Continue with automatic classification. | `Confidence >0.8` branch. |
| Unrecognized category | Review output before depending on it downstream. | Categories are limited in the README; no explicit database enum is documented. |

The project uses confidence as a guardrail, not a guarantee of correct model
classification. A future version should record model output, validation reason,
and reviewer decision for auditability.
