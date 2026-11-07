# Recovered lead-to-CRM integration

Nine original workflows and both schema migrations were recovered from the owner's WSL repository. The original checkout was read only. `manifest.json` records original and packaged SHA-256 hashes with repository-relative provenance. Exports are unwrapped, inactive and stripped of private credential references. Configure credentials in the operator's n8n UI; never insert tokens into exported nodes.

`04-outbox-legacy` and `05-replay-legacy` are synthetic reference workflows. Their synthetic success is not evidence of real CRM delivery. HubSpot and Gmail network nodes remain disabled. The planned operations service replaces the synthetic outbox consumer.

Run `node scripts/validate-crm-assets.mjs` to verify a nonempty package. Run `npm run test:crm-baseline` for disposable PostgreSQL/n8n tests using a local model stub. That harness publishes no ports, imports nothing into the owner's n8n, uses tmpfs state and removes only its uniquely named test containers. Test logs/credentials stay under ignored `.scratch/` and must never enter a public release. Live HubSpot, Gmail, model quality and booking behavior are separate validation steps.

## Foundation evidence — 7 November 2026

Validation passed for nine workflows, two migrations and three fixtures. Disposable PostgreSQL/n8n tests passed 11 scenarios: schema smoke/constraints/outbox, valid/idempotent/conflicting/consent-rejected intake, valid/repaired/review extraction and deterministic scoring. Model responses were stubbed. n8n 2.34.5 requires published child workflows, so the harness executes the recovered node graphs directly with manual fixture inputs. Published orchestration and live providers remain unverified. Exact recovered bytes are protected from Git line-ending conversion by `.gitattributes`.
