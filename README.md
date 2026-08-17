# Local AI Expense Tracker

A locally hosted AI-assisted expense processing workflow built with
n8n, Ollama, Llama 3.2, Python, PostgreSQL, and Docker.

## Project Goal

The goal of this project is to learn how deterministic workflow
automation can be combined with a locally hosted LLM.

The system receives expenses through an HTTP webhook, validates them,
uses Llama 3.2 to classify them, applies a confidence guardrail, and
stores the processed expenses in PostgreSQL.

## Architecture

Python Client
    ↓
HTTP POST
    ↓
n8n Webhook
    ↓
Expense Validation
    ↓
Basic LLM Chain
    ↓
Ollama / Llama 3.2
    ↓
Structured Output Parser
    ↓
Confidence Check
   ↙              ↘
Classified      Needs Review
   \              /
    ↓            ↓
Normalize Expense
        ↓
PostgreSQL

## Tech Stack

- n8n
- Python
- Docker
- Ollama
- Llama 3.2
- PostgreSQL

## Current Features

- HTTP webhook expense ingestion
- Input validation
- Local AI expense classification
- Structured AI output
- Confidence-based guardrail
- Human-review status for uncertain classifications
- Data normalization
- PostgreSQL persistence

## Expense Categories

- Food
- Transportation
- Utilities
- Education
- Entertainment
- Shopping
- Healthcare
- Other

## Development Progress

### Phase 1 — Validation

Built deterministic validation for:

- description
- amount
- date

### Phase 2 — Webhook Integration

Created a Python client that sends expense data to n8n using an
HTTP POST request.

### Phase 3 — Rule-Based Classification

Built deterministic expense classification using n8n Switch rules.

This demonstrated the limitations of keyword-based classification.

### Phase 4 — AI Classification

Replaced the hardcoded classification rules with a locally hosted
Llama 3.2 model through Ollama.

### Phase 5 — AI Guardrails

Added structured output containing:

- category
- confidence

Expenses above the confidence threshold are classified automatically.
Lower-confidence expenses are marked as `needs_review`.

### Phase 6 — Data Normalization

Converted the workflow output into a consistent expense object.

### Phase 7 — PostgreSQL Persistence

Added persistent storage using a dedicated PostgreSQL database.

## Example Input

```json
{
  "description": "Mang Inasal",
  "amount": 9000,
  "date": "2026-08-16"
}