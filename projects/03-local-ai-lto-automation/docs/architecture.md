# Architecture

## Purpose

The workflow extracts selected vehicle-registration fields from an LTO OR/CR
image, validates the result, stores completed registrations in PostgreSQL,
routes invalid extraction to manual review, and generates an Excel report.

## Components

| Component | Responsibility |
| --- | --- |
| n8n OR/CR workflow | Watches or manually processes a document image. |
| SHA-256 node | Creates a document hash for duplicate detection. |
| PostgreSQL | Stores registrations and manual-review records. |
| Ollama / Qwen2.5-VL | Extracts fields from the image. |
| Validation code nodes | Parses extracted values and checks validity. |
| File nodes | Read source images and copy completed/review files. |
| Excel report workflow | Creates an Excel report from completed registrations. |

## Data flow

```text
OR/CR image → hash → duplicate check → local vision extraction → parsing and validation
  ├─ valid → registration database record → completed file → Excel report
  └─ invalid → manual-review record → review file
```

Both exported workflows are inactive. Import and inspect them in a disposable
local n8n environment before testing.
