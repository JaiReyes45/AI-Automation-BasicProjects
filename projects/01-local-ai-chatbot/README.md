# Local AI Chatbot

My first AI automation workflow built using n8n, Ollama, and a locally hosted Llama model.

> **Status:** Learning prototype
>
> **Quick review:** Read the workflow below and inspect the exported
> [n8n workflow](workflows/basic-local-ai-chatbot.json).

## Goal

The goal of this project is to learn how a basic AI chatbot workflow operates and how n8n communicates with a locally hosted LLM.

## Tech Stack

- n8n
- Ollama
- Llama 3.2
- Docker
- Docker Compose

## Workflow

User Message
→ n8n Chat Trigger
→ AI Model
→ Ollama
→ Llama 3.2
→ Response

## What I Learned

- How to run n8n locally with Docker
- How to run Ollama locally
- How n8n communicates with Ollama
- Basic Docker networking
- How to connect a local LLM to n8n

## Workflow File

The exported n8n workflow is available in:

[`workflows/basic-local-ai-chatbot.json`](workflows/basic-local-ai-chatbot.json)

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/architecture.md)
- [Workflow operation](docs/workflow-operation.md)
- [Security and privacy](docs/security.md)
- [Testing and evidence](docs/testing.md)
- [Portfolio case study](docs/portfolio-case-study.md)

## Current Limitations

This is my first learning project. It currently does not include:

- RAG
- Long-term memory
- Advanced error handling
- Production monitoring

## Future Improvements

- Add conversation memory
- Add Qdrant
- Add embeddings
- Implement RAG
- Add logging and error handling
