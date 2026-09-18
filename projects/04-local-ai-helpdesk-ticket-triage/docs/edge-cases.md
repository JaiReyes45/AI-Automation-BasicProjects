# Edge cases

| Case | Safe handling |
|---|---|
| Empty subject/description, invalid email, oversized content | Reject before model invocation. |
| Duplicate submission or retry | Unique idempotency key returns the original ticket; no second notification. |
| Multiple issues, ambiguity, unsupported language | Store ticket and route to manual review. |
| Abusive text, PII, secrets, prompt injection | Treat content as untrusted data; redact logs and route review. |
| Account takeover or active security incident | Force security queue, P1, and human review. |
| Invalid JSON, unknown category, invalid confidence | Record invalid run; retry three times; then fallback to unknown/manual review. |
| Ollama timeout | Preserve ticket; use bounded retry then manual review. |
| PostgreSQL unavailable | Do not claim acceptance. Return a temporary safe failure. |
| Mailpit unavailable | Preserve a unique outbox item and retry without losing ticket state. |
| Weekend/out-of-hours SLA | Use Asia/Manila business hours; P1 remains 24x7. |
| Container restart | Resume from persisted state only; do not trust in-memory execution state. |
