# Construction CRM

A private engineer’s desk with a cute pixel construction site. Commission real coding work in **Build** mode, and observe hosted lead intake, CRM delivery and consultation bookings in **Operate** mode. Animation and replay make no AI calls.

## Use it

- **Engineer:** clone or extract this repository, install Node.js 22.13+, Git and an authenticated Codex CLI, then run `npm.cmd start`. Register a workspace, choose an advertised model and available skills, commission work and review its evidence.
- **Customer:** open your separately hosted enquiry page, submit an enquiry and use the consultation calendar. No installation or GitHub account is needed.
- **Demo visitor:** run `npm.cmd run demo:site`, or host the static `demo/` page and its relative assets on GitHub Pages. It uses synthetic events only.

The V1 product is a browser app with a local server, plus a separate always-on hosted backend. An app-store/mobile build and desktop wrapper are outside V1. GitHub distributes source; GitHub Pages cannot run the database, workers, n8n or coding runner.

```powershell
npm.cmd run doctor
npm.cmd test
npm.cmd start
```

The local runtime has no npm dependencies. The separately packaged hosted service uses lockfile-pinned `pg`. See [local installation](docs/install-local.md), [hosted deployment](docs/deploy-operations.md), [operator recovery](docs/operator-recovery.md) and [architecture](docs/construction-architecture.md).

Build defaults to one active model task, maximum two with explicit admission. A task-start budget and 20-minute deadline are enforced. Token usage is measured when reported and otherwise shown as unknown; hard token enforcement is unavailable. Skills are instruction packages used by a runtime actor. Selection does not prove invocation or causal attribution. Runtime permission requests approve one exact action only. Unknown requests decline.

Meaningful progress comes from evidence. Failed/cancelled work cannot complete buildings. Public receipt, qualification, CRM delivery and verified booking are independent states. Missing provider configuration enters review. A confirmed consultation can coexist with a CRM retry. The private local runner never accepts cloud-issued arbitrary commands.

The original recorder remains at **Run diagnostics** (`/diagnostics`) with timeline, replay, failures, exports and opt-in bounded redacted tool content. Prompts and reasoning are not persisted; commission instructions stay in memory. Data lives in `.data/events.db` by default. Keep its bearer token private and its listener on loopback.

## Verification and release

```powershell
npm.cmd --prefix services/operations ci --ignore-scripts
npm.cmd run test:operations-db
npm.cmd run pilot:system -- --synthetic
npm.cmd run pilot:build -- --synthetic
npm.cmd run package -- --out .scratch/release/construction-source
npm.cmd run verify:release -- .scratch/release/construction-source
```

Docker is required for the explicit PostgreSQL/system/release checks. Ordinary local tests remain Docker-independent. Packaging names every source file, preserves SHA-256 hashes and refuses to overwrite an existing release. Credentials, private databases, customer data and local machine paths are excluded. [Notices](docs/third-party-notices.md) and the proposed MIT license are included for owner review before publication.

The local and synthetic journeys have passing evidence. The published private n8n bridge has separate disposable-stack evidence with a model stub. The HubSpot sandbox and controlled GHL booking journey have live-account evidence. GHL credential rotation, a selected hosted model, the complete owner accessibility journey and actual production deployment remain gated. See [release readiness](docs/verification/release-readiness.md). No repository push or public deployment has been performed.
