# Isolated installation verification

The source packager uses an explicit allowlist, regular-file/root checks, SHA-256 hashes and create-only output. Source-link escape and private canary tests pass.

Verification copies only manifest-listed files into a temporary isolated checkout. It boots the local app with a generated bearer and temporary SQLite DB, checks its required public assets and explicit unconfigured-operations state, installs only the hosted lockfile dependencies, then applies all seven migrations and accepts a durable synthetic lead on a fresh PostgreSQL container. The reviewed source artifact is not mutated by installation checks.

Observed R2 verification: all manifest hashes matched; local and hosted clean boot passed; demo authority isolation and canary exclusions passed. The initial verified artifact contained171 files. Subsequent QA/management tests are included in the final manifest and require a fresh final verification.

Production Compose syntax validated without starting the stack. Production container build, DNS/TLS issuance, private n8n publication, provider credentials and deployment are pending and are not inferred from this smoke test.
Final R2 artifact: construction-r2-verified,174 files; all manifest hashes, isolated local/hosted boot, demo isolation and canary checks passed (.scratch/r2-verify-final.log). Local regressions83/83; hosted regressions9/9 with backup/restore.
R3 review snapshot:178 files; all isolated checks passed. --require-ready correctly returned exit2 with five pending live/human gates. Root85/85; hosted9/9 plus backup/restore; recovered n8n baseline12 checks; separately published private n8n bridge passed with a stub model.


Final review fix suite:91/91 local tests and19/19 PostgreSQL integration tests, including a logical backup restored into a fresh database. The new regressions cover qualification health, dependency wake-up after acceptance/checks, real crew-role assignment, terminal job projection, audited review recovery, booking/CRM arrival order and cancellation races, offline runtime discovery, and continued bounded receipt observation. See post-review.md. A new create-only source snapshot and its generated release-verification.json are the final install evidence; earlier snapshots above remain historical.

Live-account follow-up:92/92 local tests and20/20 PostgreSQL tests plus restore passed after the actual GHL appointment-envelope correction and changed-time regression. HubSpot and controlled GHL API evidence are documented in live-accounts.md. A new immutable live-tested source package receives a separate isolated installation check.
