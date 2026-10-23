# D2.1 — First classification exercise

## Purpose

Convert an email into structured fields: stage, role, company, and application
reference. Later, n8n will pass email content to this component. The matching
rules will decide which application can be updated before anything is saved.

## Your task

Open your Ubuntu/WSL terminal and run:

```bash
cd /home/guienne_jairo_reyes/code/AI-Automation-BasicProjects/projects/07-automated-career-opportunity-manager
python3 -m workflow.preview fixtures/application-submitted.json
```

This is a host-side diagnostic of the draft engine, not a deployed Docker
workflow. It requires only Python's standard library. The web app stays in
Docker. The engine will be containerized when its rules have been verified.

## Expected result

- `stage`: `submitted` (the internal name for Application Submitted)
- `role`: `QA Engineer Intern`
- `company`: `Example Labs`
- `reference`: `APP-007`
- `proposed_action`: `create`
- `records_written`: `0`
- `gmail_connected`: `false`

Inspect the evidence phrase and confirm it occurs in the synthetic email.
`create` is only a proposed decision: this preview does not save an application.

## What this teaches

Classification answers “what happened?” Matching answers “which application?”
Saving and applying Gmail labels are later steps. Separating them lets us test
the interpretation without altering the inbox or database.

## Current limits

This first fixture uses explicit Company/Role/Reference lines. It does not prove
that arbitrary Indeed or JobStreet emails can be parsed. Missing fields,
conflicting signals, quoted replies, duplicate messages, and application identity
will be tested next. D2.1 remains in progress until that matrix passes.
