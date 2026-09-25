# Architecture

## Purpose

The chatbot demonstrates the smallest useful local AI automation: n8n accepts a
chat message and sends it to a locally hosted Llama model through Ollama.

## Components

| Component | Responsibility |
| --- | --- |
| n8n Chat Trigger | Receives a user message in n8n's chat interface. |
| Basic LLM Chain | Passes the message to the configured language model. |
| Ollama Chat Model | Connects the chain to the local Llama 3.2 model. |
| Docker Compose | Provides the local service environment. |

## Data flow

```text
User message → n8n Chat Trigger → Basic LLM Chain → Ollama / Llama 3.2 → response
```

The workflow has no database, memory store, external SaaS integration, or
durable audit trail. It is a learning architecture, not a support system.
