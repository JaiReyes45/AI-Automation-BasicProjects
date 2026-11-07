# Release readiness

**Ready for source review and local use. Production readiness: pending. Publication/deployment permission: not granted.**

The source installer, static demo, local Build journey and synthetic hybrid CRM journey have passing evidence. A real Codex task produced a reviewed diff and a passing process check; its owner release decision remains pending. The complete source package is tested in an isolated copy with temporary SQLite/PostgreSQL storage. The production deployment template has been syntax-checked, not deployed.

Remaining required gates:

1. Select and verify an always-on extraction model's512-token/15-second contract.
2. Owner rotates the read-only GHL credential before activation, then verifies the chosen signed webhook subscription or listing/reconciliation strategy on the target host. The controlled live create/reschedule/cancel journey passed; its appointment is cancelled. The current token appeared in a tool result and is not accepted for production release.
3. Owner completes the keyboard-only, screen-reader and reduced-motion journey, including the public calendar's compulsory marketing-consent behavior.
4. Owner reviews source/license, implementation, target-host deployment and production provider configuration before release. Review permission and publication permission are separate.

The HubSpot sandbox capability gate passed with real returned IDs, returning-contact reuse, associations and replay protection. Its two clearly labelled test deals remain for owner review; scheduled-stage automation stays disabled. Both provider credentials were created within the approved scopes and stored using Windows user encryption outside the synced checkout. No account tokens appear in the source artifact.

See live-accounts.md and live-account-report.json for the exact evidence boundary. The GHL admin journey and captured-response database replay do not establish a working public signed callback or production deployment.

Proposed hosted surface: HTTPS at the owner's chosen domain, public enquiry/receipt/calendar routes and signed GHL callback. Owner endpoints require an expiring bearer token. PostgreSQL/n8n/qualification remain private, and the coding runner stays loopback-only. See docs/deploy-operations.md for the concrete template and docs/operator-recovery.md for owner-token recovery.

The machine-readable verifier keeps these pending even when installation and fixture suites pass. Passing code tests alone cannot turn this status into production approval.
