# Workflow operation

## Input contract

The sample client sends JSON with:

```json
{
  "description": "YouTube subscription",
  "amount": 300,
  "date": "2026-08-18"
}
```

The project README identifies `description`, `amount`, and `date` as the
validated input fields. Use synthetic expenses when demonstrating the workflow.

## Normal path

1. A client posts an expense to the n8n webhook.
2. The validation node accepts or rejects the input.
3. Ollama classifies the description through a Basic LLM Chain.
4. The Structured Output Parser supplies category and confidence fields.
5. The confidence branch marks the result as automatically classified or
   `needs_review`.
6. A Set node normalizes the selected result.
7. PostgreSQL saves the expense.

The included [Python client](../python/send_expense.py) contains a development
webhook-test URL. Replace it with the current local test URL when running an
imported copy; do not publish an active production webhook URL.
