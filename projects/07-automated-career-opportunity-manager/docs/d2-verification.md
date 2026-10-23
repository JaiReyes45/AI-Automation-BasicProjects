# Day 2 verification — October 23, 2026 (Asia/Manila)

## Scope

D2.1 controlled classification/matching and D2.2 local synthetic orchestration.
No real email was read, labeled, sent, or used as fixture data.

## Automated checks

Run `python3 -m unittest discover -s tests -v` from the project folder.
20 tests cover a 16-case classification matrix, role aliases, invalid envelopes,
unknown fields, old subjects, matching, account isolation, duplicated/concurrent
deliveries, stale events, closed applications, label preservation, retry recovery,
and bounded repeated failures.

Run `python3 projects/07-automated-career-opportunity-manager/scripts/verify_n8n.py`
from the portfolio repository root after importing the workflows. This executes
real n8n nodes against the internal engine service and saves only a sanitized
summary in `docs/n8n-verification.json`. Workflow 04 is supposed to fail.

## Visible workflows

1. Synthetic email intake: manual trigger → synthetic fixture → classify/match/store → inspect outcome.
2. Simulated label delivery: durable jobs → mock mailbox → report errors or success.
3. End-to-end duplicate and recovery test: submission → duplicate → interview → simulated delivery outage → retry → assertions.
4. Expected invalid-input failure: invalid request → three bounded HTTP attempts → explicit error branch.

These workflows are inactive and contain only synthetic data and non-secret
credential references. No polling, scheduled job, or Gmail trigger is activated.

## Limitations and deferred work

- Gmail OAuth and actual Gmail-label mutation: blocked on D3.2 setup, not tested.
- Flutter is still a read-only sample workspace; it does not display the engine's records.
- SQLite is a durable synthetic test adapter. PostgreSQL currently stores n8n's data only.
- Arbitrary employer templates, sender authenticity, attachments, calibrated probability,
  full manual-review UI, and production retry scheduling are not implemented.
- n8n logs mention its optional Python task runner is absent. The workflows use
  JavaScript nodes and HTTP; Python runs in the separate engine container.
- Local-only deployment requires Docker Desktop and an awake device.
