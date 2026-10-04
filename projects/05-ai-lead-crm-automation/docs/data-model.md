# Project 05 Data Model

## Status

Implemented and locally tested against PostgreSQL 16.

## System of record

PostgreSQL is the authoritative store for companies, contacts, lead submissions, opportunities, activities, and audit history.

HubSpot will later become the sales-facing CRM. Gmail will be a communication channel. Google Sheets may later receive a one-way reporting view, but it will not be the authoritative database.

## Core entities

### Companies

Represents an organization that may be a prospect, active client, or former client.

A company can have multiple contacts, submissions, opportunities, and activities.

### Contacts

Represents an individual associated with a company.

The normalized email address is unique and acts as the deterministic person-level duplicate key.

### Lead submissions

Represents one inbound enquiry.

Each submission contains:

- An external `submission_id` for idempotency
- An internal correlation ID for tracing
- Raw and normalized payloads
- Processing status
- Validation results
- AI extraction fields
- Deterministic score and qualification
- An optional link to an earlier duplicate submission

Repeated delivery of the same `submission_id` must not create another record.

### Opportunities

Represents one potential paid engagement.

An opportunity belongs to an existing company and contact. Its relationship type distinguishes new business from a returning client.

A returning client is therefore an existing company with a new opportunity after earlier successful work—not a duplicate company or contact.

### Activities

Represents communication or business activity such as Gmail messages, Mailpit tests, meetings, notes, notifications, and CRM synchronization.

External message IDs prevent the same Gmail message from being recorded more than once.

### Audit events

Provides an append-oriented history of workflow actions, lifecycle transitions, scoring outcomes, reviews, and integration results using a shared correlation ID.

## Implemented database protections

- Unique normalized contact email
- Unique external submission ID
- Unique correlation ID
- Foreign-key relationships
- Lead-score range enforcement
- Controlled lifecycle and sales-stage values
- External-message deduplication
- Prevention of orphan activities
- Automatic `updated_at` maintenance
- Transactional migration execution

## Verification

The schema passed:

1. A rollback-safe relational smoke test covering all core tables.
2. Duplicate normalized-email rejection.
3. Duplicate submission-ID rejection.
4. Invalid lead-score rejection.
5. Orphan-activity rejection.

All test records were rolled back and no synthetic test data was retained.
