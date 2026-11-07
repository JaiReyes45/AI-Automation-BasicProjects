# Acceptance matrix

| Requirement | Status | Source | Evidence |
|---|---|---|---|
| Bounded Build tasks, dependency/cancel/check evidence | passed | synthetic | Local test suite; build pilot |
| One real coding change, real exit check, measured usage/replay | passed | real-runtime | docs/build-pilot.md |
| Cute pixel scene, independent HTML controls, no per-frame AI | passed | synthetic/browser | docs/qa/construction-dashboard.md; docs/qa/public-and-demo.md |
| 20 durable leads with local service stopped | passed | synthetic, real HTTP/SQLite/PostgreSQL | docs/verification/system-pilot.md |
| Private published n8n bridge, bounded/duplicate-safe extraction | passed | synthetic, real n8n/PostgreSQL | docs/verification/private-n8n-bridge.md |
| Selected always-on model contract | pending | real-runtime required | docs/qualification-adapter.md |
| CRM partial writes, leases, auth/rate failures and reconciliation | passed | fake-provider/PostgreSQL | Hosted suite |
| Actual HubSpot returned IDs and configured pipeline/property policy | pending | test-account required | docs/hubspot-capability-spike.md |
| Booking cancellation/order/DST/ambiguity and CRM independence | passed | synthetic/PostgreSQL | Hosted suite |
| Existing30-minute GHL widget and fallback | passed | browser read-only | docs/booking-capability-spike.md |
| Actual GHL create/cancel/reschedule and canonical server reads | pending | test-account required | docs/booking-capability-spike.md |
| Hosted auth revoked, Build remains usable, no cloud dispatch | passed | synthetic/HTTP | Operations boundary and event tests |
| Source canaries/links, clean local/hosted install, static demo isolation | passed | isolated installation | docs/verification/clean-install.md |
| Desktop/390px reflow and keyboard selection spot checks | passed | agent-operated browser, synthetic records | docs/qa/public-and-demo.md |
| Full owner keyboard, screen-reader and preference-toggle journey | pending | human required | docs/qa/public-and-demo.md |
| Owner accepts implementation/release | pending | human required | docs/verification/release-readiness.md |
| Production image build, DNS/TLS, deployment and publication | pending | approved deployment required | docs/deploy-operations.md |
| Desktop/mobile packaging and multi-tenant accounts | not_in_v1 | approved scope | docs/construction-architecture.md |

No synthetic entry substitutes for a required real-runtime, test-account or owner check. `evidence.json` supplies categorized readiness records. The source verifier returns `ready:false` while required live/human entries are pending. `--require-ready` exits with a nonzero status in that state.
