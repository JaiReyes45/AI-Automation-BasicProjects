# Local AI LTO OR/CR Automation

A fully local AI-powered document processing workflow for extracting
vehicle registration information from Philippine LTO OR/CR documents.

> **Status:** Prototype
>
> **Quick review:** Demonstrates a document-automation pipeline with duplicate
> detection, local vision extraction, validation, persistence, reporting, and a
> manual-review path for invalid results.

## Stack

- n8n
- Docker
- PostgreSQL
- Ollama
- Qwen2.5-VL 7B
- Microsoft Excel

## Workflow

OR/CR PNG
→ SHA-256 Duplicate Detection
→ Qwen2.5-VL Extraction
→ Validation
→ PostgreSQL
→ Excel Reporting

Invalid extraction
→ Manual Review

## Extracted Fields

- Plate Number
- Vehicle Type
- MVUC
- Legal Research Fee
- Penalty

## Business Rules

Amount Paid = MVUC + Legal Research Fee + Penalty

Freelancer compensation = PHP 250 per completed registration.

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/architecture.md)
- [Workflow operation](docs/workflow-operation.md)
- [Security and privacy](docs/security.md)
- [Testing and evidence](docs/testing.md)
- [Portfolio case study](docs/portfolio-case-study.md)
