# Edge cases and validation

| Scenario | Intended handling | Supporting artifact |
| --- | --- | --- |
| Duplicate document | Detect matching SHA-256 hash and mark it as duplicate. | `Generate Document Hash`, `Check Duplicate`, and `Is Duplicate?` nodes. |
| Unreadable image | Do not save incomplete registration data as completed. | Parse/validation path and manual review. |
| Missing extracted field | Route to manual review. | `Extraction Valid?` branch and `manual_reviews` schema. |
| Negative fee | Reject invalid amount. | PostgreSQL `CHECK (... >= 0)` constraints. |
| Repeated manual-review document | Preserve one review record per hash. | `manual_reviews.document_hash` is unique. |

The schema protects non-negative fee values and duplicate hashes, but model
extraction still requires validation and human review. The workflow must not
treat a vision-model response as authoritative vehicle-registration data.
