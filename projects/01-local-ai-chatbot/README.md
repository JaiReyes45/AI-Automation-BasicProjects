# Local AI Chatbot

My first AI automation workflow built using n8n, Ollama, and a locally hosted Llama model.

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

`workflows/basic-local-ai-chatbot.json`

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

