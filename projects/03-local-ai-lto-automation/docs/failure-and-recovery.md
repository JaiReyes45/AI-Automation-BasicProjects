# Failure and recovery

## Current safety path

Invalid extraction is routed to a manual-review record instead of being saved
as a completed registration. The `manual_reviews` table stores the document
hash, filename, nullable extracted fields, validation errors, review status,
and timestamps.

## Gaps to resolve before operational use

- No documented bounded retry or timeout behavior for model calls.
- No recorded operational procedure for PostgreSQL, file-system, or Excel-write failures.
- No documented reviewer-resolution workflow for changing a manual-review item to resolved.
- No controlled evidence that duplicate file handling is idempotent end to end.

## Recommended recovery design

Log a correlation ID and bounded failure context, retain the original document
only within an approved private storage boundary, and provide an audited review
resolution process. Do not replay a failed item blindly if it can create a
second registration or duplicate report row.
