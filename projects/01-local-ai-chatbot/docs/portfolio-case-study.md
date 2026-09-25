# Portfolio case study: Local AI Chatbot

## Problem

Learn the basic mechanics of connecting an automation tool to a local language
model without relying on a hosted AI service.

## Solution

Created a three-node n8n workflow that receives a chat message, passes it
through an LLM chain, and invokes Llama 3.2 through local Ollama.

## What it demonstrates

- Local Docker-based AI development
- n8n chat triggers and LangChain nodes
- Local-model connectivity

## Honest scope

This is a learning prototype. It does not yet provide persistence, evaluation,
guardrails, authentication, monitoring, or recovery controls.

## Next milestone

Record a controlled synthetic demo and add safe error handling before extending
the chatbot with memory or retrieval.
