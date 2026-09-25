# Portfolio case study: Local AI LTO OR/CR Automation

## Problem

Vehicle-registration documents contain repetitive structured fields that are
time-consuming to enter manually, while extraction errors can affect fees,
records, and reporting.

## Solution

Designed a local n8n workflow that hashes incoming images, checks for duplicates,
uses a local vision model for extraction, validates values, persists completed
records, and routes uncertain documents to manual review.

## What it demonstrates

- Vision-model integration with automation workflows
- Duplicate detection using document hashes
- Database-level data constraints
- Manual-review routing for unreliable extraction
- Excel report generation

## Honest scope

This is a prototype. It has no recorded controlled-demo result and does not yet
document the security, retention, access-control, or recovery practices needed
for processing real registration documents.

## Next milestone

Use only synthetic/redacted document fixtures to execute and record the test
matrix, then add an audited manual-review resolution process.
