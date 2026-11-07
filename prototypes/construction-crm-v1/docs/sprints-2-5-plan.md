# Remaining sprint execution plan

Authorized 2026-10-31. Baseline commit 4459749. Continue current feature branch, preserve existing recorder APIs, local-only deployment, no new registry dependencies.

## Global constraints

- Requested/available/observed are distinct. File reads are evidence of loading, never proof of skill-to-tool causality.
- Metadata-only by default. Content capture is explicit per run, redacted before disk write, bounded, local, and visibly marked.
- No automatic config edits, skill installation, approvals, destructive Git commands, or public deployment.
- Evidence drives animation and replay. Unknown attribution stays unknown. A completed run may contain failed tools.
- Scripts are cross-platform Node where practical; Windows is the verified release target.
- External human pilot timing cannot be fabricated. Run five automated fixture projects and clearly leave the human pilot measurement pending.

## Task 1: Inventory and change-inspection libraries (Sol High)

Create src/inventory.mjs, src/changes.mjs, src/diagnostics.mjs and focused test/*.test.mjs. Test first. No server/store/CLI/UI edits.

Interfaces: discoverSkills(cwd,{clientFactory}={}) -> Promise<{skills,capabilities}>. Each skill: {id,name,description,path,scope,origin,hash,available,kind:'skill',plugin:string|null}; use Codex skills/list, read actual bounded SKILL.md to hash, avoid executing content. IDs stable by canonical path; preserve duplicates and explicit enabled=false. Validate selection with selectSkills(inventory,ids) -> selected skill array; reject unknown/unavailable IDs.

snapshotWorkspace(cwd) -> {supported,reason?,files:[{path,hash,content?,omitted?}],head?,dirty?}. Git tracked and untracked nonignored files; relative paths only, reject symlinks, binaries, secrets filenames, huge files and excessive count, bounded output. compareSnapshots(before,after,{captureContent:false}) -> changes [{path,beforeHash,afterHash,kind,attribution:'unattributed',diff?,omitted?}]. Exclude pre-existing dirt from claimed changes by comparing the actual baseline, not HEAD.

redact(text) -> bounded string; removes credentials/tokens/env secrets. inspectFailure(events,eventId) -> {event,category,preceding,parent?,related,attribution:'unknown'}; use runtime IDs for tool matching, no guessed reasoning. exportBundle(detail) -> plain redacted diagnostic object safe for JSON download; omit prompts and workspace absolute paths.

Meaningful tests: duplicate names/scopes, unavailable expected set, secret filtering, dirty baseline preserved, manual edits remain unattributed, large/binary/symlink exclusion, exact failed-event correlation, redacted export. Use disposable Git repos and fake protocol transport only where Codex external dependency is needed.

## Task 2: Integrated service and data model (controller, Sol High)

Add run detail persistence and migrations to Store. Create src/runner.mjs managing initialized Codex lifecycle, skill preflight + explicit skill input, snapshot baseline/final, optional bounded tool output capture, cancellation and errors. Expose authenticated same-origin APIs:

- GET /inventory?workspace=absolute-path -> {skills,capabilities}
- POST /launch {workspace,prompt,expectedSkillIds:[],captureContent:false,model?,effort?} -> {runId}
- POST /runs/:id/cancel; GET /runs/:id -> {runId,status,eventCount,events,details}
- GET /runs/:id/export -> redacted bundle; POST /retention {days}; GET /health -> health/capabilities
- Static /, /app.mjs, /style.css, /projection.mjs (no data in unauthenticated page). Bearer API auth. Only matching loopback Origin allowed; enforce Host to avoid DNS rebinding. Dashboard stores token in sessionStorage, never URL.

Store details: {workspaceLabel,expectedSkills,inventory,captureContent,changes,diagnostics,model,effort}; no prompt persistence. Preserve IDs for source evidence and output only when opted in. Add lifecycle source event context to inspector.

## Task 3: Live visual debugger (Terra High)

Create public/index.html, public/style.css, public/app.mjs, public/projection.mjs; no backend edits. Operate-mode professional developer tool, construction/blueprint scene with agent/tool workers, affected zones, visible evidence and unknown attribution. Sidebar run list; launch form with workspace, inventory, skill selection, capture toggle, model/effort; three-pane live scene/timeline/inspector. SSE via authenticated fetch reader. Cursor reconnect, heartbeat freshness/disconnect state, no fake animation. Pause scene playback independent of running agent, scrub, speed, filters, failure jump, table view, replay. Inspector includes event IDs, preceding matched tool, payload, changes/diffs, export. Keyboard/focus/reduced-motion support and responsive layout. Pure deterministic projection export for tests. User strings rendered with textContent. Empty state and demo fixture clearly labeled synthetic. No external assets/fonts. Write PRODUCT.md and DESIGN.md from existing brief; inspect rendered UI when runtime accessible.

## Task 4: Release and five-project automated pilot (Sol Medium)

Create scripts/package.mjs, scripts/doctor.mjs, scripts/pilot.mjs, docs/release-report.md, docs/human-pilot.md. Package local source into .scratch/release using allowlist, exclude private DBs and fixtures containing user data. Doctor checks Node/Codex/Git and reports safe actionable health. Pilot creates five disposable Git projects exercising success, failed tool/test command, interrupted/crashed run, missing/late events and manual drift; verify actual store/runner boundaries. Record automated evidence, leave human median-diagnosis timing pending. Document onboarding, uninstall without modifying projects, retention/export and optional capture limitations.

## Review and verification

Each code task uses focused red/green tests. Final suite, five-project pilot, syntax checks, loopback API live test, real inventory call, real Codex task where account permits, and desktop/mobile screenshot QA. Astra High whole-branch review. Fix material findings before final report. Keep local branch; commit reviewable milestones. No push/publish.
