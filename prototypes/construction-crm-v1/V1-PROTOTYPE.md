# Construction CRM — V1 prototype

Frozen from local source commit fcac869 on 7 November 2026. This is the preserved, installable V1 prototype; V2 will be designed separately. Existing projects in this repository are unchanged.

The prototype includes the private local Build dashboard, original pixel sprites, deterministic replay, task/approval/evidence recording, hosted CRM service source, deployment templates, architecture and tests. It is not a production deployment or a ready-made Codex/Claude companion plugin.

Historical checks:92 local tests,20 PostgreSQL tests plus restore, actual Codex task evidence, controlled HubSpot adapter tests and a GHL create/reschedule/cancel journey. The test appointment was cancelled. The always-on model, target-host deployment and owner acceptance remain pending.

Privacy: credentials, personal contact details, provider-account identifiers, runtime databases, local caches and machine-specific internal planning history are excluded from this public snapshot. Historical live account IDs have been redacted in documentation. Every new installation must configure and verify its own providers. Original CRM provenance assets and their hashes are preserved. The full development history and private evidence remain in the original local checkout.

- [Start locally](docs/install-local.md)
- [Architecture](docs/diagrams/construction-crm-architecture.html)
- [Narrated tutorial](docs/tutorial/construction-crm-tutorial.mp4)
- [Transcript](docs/tutorial/transcript.md)
- [Readiness](docs/verification/release-readiness.md)
- [License](LICENSE) and [notices](docs/third-party-notices.md)

The source runtime and tests are unchanged. Only public-documentation identifiers and installation-specific readiness records were sanitized for archival publication.

The verified archival tag is construction-crm-v1-prototype-verified. V1-SNAPSHOT.json hashes refer to committed Git blob bytes so the canonical archive is reproducible across platforms. The initial prototype tag is retained as historical provenance; only the archival manifest and this note were corrected afterward. Runtime files are unchanged.
