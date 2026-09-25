# Architecture

## Purpose

The Expense Tracker accepts an expense through an n8n webhook, validates its
core fields, asks a local Llama 3.2 model to classify it, applies a confidence
guardrail, normalizes the result, and saves it to PostgreSQL.

## Components

| Component | Responsibility |
| --- | --- |
| Python client | Sends a sample expense HTTP request. |
| n8n Webhook | Receives the expense payload. |
| Validation node | Checks required input before AI processing. |
| Ollama and Llama 3.2 | Produces a category and confidence value. |
| Structured Output Parser | Shapes model output for the workflow. |
| Confidence Check | Selects automatic classification or `needs_review`. |
| PostgreSQL node | Persists the normalized expense record. |

## Data flow

```text
Python client → webhook → validation → local AI classification
→ structured output → confidence guardrail → normalization → PostgreSQL
```

The design demonstrates a useful boundary: AI suggests a category, while a
deterministic confidence threshold decides whether automation may continue.
