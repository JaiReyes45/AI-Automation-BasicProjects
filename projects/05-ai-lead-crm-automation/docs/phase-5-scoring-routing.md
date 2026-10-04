# Phase 5 — Deterministic Scoring, Duplicate Context, and Routing

## What this phase does

Workflow `03 - Deterministic Scoring and Routing` turns validated facts into a
repeatable business decision. AI does not award points. The same input always
produces the same score.

## Beginner mental model

Think of the workflow as a calculator followed by a traffic controller:

1. PostgreSQL loads the complete lead and checks whether the email already
   belongs to a known contact.
2. A Code node applies the published V1 point table.
3. PostgreSQL stores the score, qualification, rule version, and audit event.
4. Leads that need judgment enter `review_queue`.
5. Eligible leads enter `CRM_SYNC_PENDING` and receive an idempotent outbox job.

## Factors

The maximum is 100 points: service fit 25, budget 20, company size 15,
timeline 15, decision-maker evidence 10, business email 10, and Philippine
market fit 5. Missing facts receive zero points; they are never invented.

## Duplicate and returning-client context

The workflow looks up `contacts.email_normalized`. A match is reported as
`existing_contact_match`. If the matched company is an active or former client,
the relationship type becomes `RETURNING_CLIENT`; otherwise it is
`NEW_BUSINESS`. This is separate from submission-ID idempotency in Workflow 01.

## Human review guardrails

Automatic CRM routing stops when:

- AI confidence is below `0.65`; or
- the extracted country is explicitly outside the Philippines.

The lead is preserved with `REVIEW_REQUIRED`; it is not rejected.

## Verified result

The controlled Phase 4 seed scored `50`, qualified as `WARM`, moved to
`CRM_SYNC_PENDING`, and created one idempotent CRM outbox job. The result was
correct because its deliberately minimal stored payload did not state budget,
company size, or purchase timeline.
