# Agent Control Center — sprint plan

Status: Sprints 0–1 executed on 2026-10-30; Sprints 2–5 technical implementation and automated release checks executed on 2026-10-31. The Sprint 5 human pilot and diagnosis-time benchmark remain pending real participants. See [QA report](qa-report.md), [release report](release-report.md), and [human pilot protocol](human-pilot.md). Actual integration boundaries remain explicit.

## Delivery shape

Six one-week sprints for one developer, with a reviewable demo at the end of each week. The schedule is an estimate; the Codex integration spike in Sprint 0 can change it. Keep one vertical slice working at all times. Each sprint ends with a demo, automated checks for the behavior it adds, and a list of observed coverage gaps.

| Sprint | Outcome | Demo / acceptance gate |
|---|---|---|
| 0 — Integration proof | Confirm Codex event sources, skill inventory locations, and attach/launch limits | A real Codex task produces captured session, tool, and completion events; unsupported signals documented with evidence |
| 1 — Run recorder | Persistent, replayable event ingestion | Run survives collector restart; duplicate and late events do not corrupt order/state |
| 2 — Skill inventory and attribution | Expected-versus-observed skill view | Developer can identify configured skills, observe a proven activation, and see unknown attribution clearly |
| 3 — Diff and failure inspector | Connect errors and file changes to runs | A failing test opens its tool result, context, changed files, and evidence labels |
| 4 — Live visual debugger | Synchronized construction view and timeline | A real task animates from events; pause/scrub/filter works; disconnect freezes with status |
| 5 — Hardening and pilot | Reliable local release for developer trials | Five real projects and failure scenarios pass the pilot checklist; install/uninstall and data controls work |

## Sprint 0 — prove the integration (highest risk)

**Work:** Inventory the installed Codex version and its documented app-server/hook schema. Run controlled tasks that read a skill, call a tool, edit a file, fail a command, request approval, and finish. Record which signals are directly exposed, which require logs or hooks, and which cannot be observed. Test whether an external client can attach to an existing desktop session. Make an adapter capability matrix and event fixtures. Sketch a small clickable flow for run list → live run → failed event inspector, without production UI.

**Gate:** Do not start the full build until at least session/turn lifecycle, tool start/end, and run completion are capturable from a supported Codex path. If existing-session attachment is unavailable, scope the MVP to "Launch with Control Center." If skill activation is not directly exposed, show `skill_file_read` or another precise signal rather than claiming invocation.

## Sprint 1 — event spine

**Work:** Create local collector, canonical event envelope, append-only SQLite tables, migrations, source adapters, deduplication, timestamp handling, and replay projection. Add a local API and SSE stream. If Sprint 0 selects client-owned app-server mode, implement launch, prompt submission, session connection, completion/cancellation observation, and cleanup in this sprint; otherwise implement supported attachment lifecycle. Provide a CLI fixture importer so UI work does not depend on a live agent. Capture collector health and connection status. Sanitize source envelopes before persistence.

**Gate:** A live or fixture run streams into storage and replays identically after restart; 1,000 events remain ordered by source sequence with late arrivals marked; malformed events are rejected without stopping ingestion. A disconnected dashboard reconnects without losing persisted history. A launched or attached run has a verified start-to-finish lifecycle. Sensitive fixture payloads do not appear in the database.

## Sprint 2 — inventory and skill evidence

**Work:** Scan Codex skill/plugin locations without executing content. Record scope, origin, content hash, effective availability, and duplicate names. Add prompt-and-expected-set submission in launch mode, or expected-set annotation for externally started runs. Preflight selected component availability without claiming activation. Build the skill registry and run-side panel that distinguishes available, requested, observed, and unproven. Link every observed label to its sanitized source event. Add a capability coverage panel.

**Gate:** A developer can explain why each skill is listed and why a skill was marked used or merely available. A requested skill with no activation appears as `not observed`, never as `unused`. Conflicting names across scopes remain distinguishable. A skill load without explicit causal IDs does not claim ownership of later tool calls.

## Sprint 3 — changes and failure diagnosis

**Work:** Capture Git baseline and post-run diff, including dirty starting worktree. Associate edits with events only where evidence permits. Normalize command/test failures, policy denials, timeouts, and cancellation. Build failure inspector with raw event, parent chain, stderr, diff, and neighboring timeline. Add redacted diagnostic export.

**Gate:** A seeded failing test and a real failing Codex task show the exact failure and affected files. A simultaneous manual edit is marked unattributed. Binary/large files and secrets are omitted or summarized safely. Export reopens locally without exposing captured credentials.

## Sprint 4 — visual debugger

**Work:** Implement the three-pane UI: build scene, event timeline, inspector. Define a deterministic event-to-animation mapping and a compact visual grammar for agent, skill, tool, file, approval, and failure. Add pause, scrub, speed control, filters, jump-to-failure, and dense table fallback. Persist no independent animation state; derive it from the event projection.

**Gate:** Live animation and replay render the same state for the same event sequence. Every visual action opens its evidence. An unobserved step is visually distinct, and an interrupted stream freezes with last-event time. Keyboard navigation and reduced-motion mode remain usable.

## Sprint 5 — release pilot

**Work:** Package for the chosen operating system, add onboarding and an integration health check, retention settings, redaction review, local authentication, recovery after crash, and diagnostics. Pilot on five diverse Git projects with at least one passing run, one tool failure, one test failure, one interrupted run, and one run with missing events. Record developer feedback on time-to-find-failure and trust in attribution.

**Gate:** No claim of full coverage without evidence. A developer can find the cause of a seeded failure faster with the dashboard than by browsing raw logs; target median under two minutes across pilot tasks. Installation and uninstall leave project files untouched. Pilot issues are prioritized before expanding agent support.

## Later phases, contingent on pilot

- **Phase 2:** Claude Code adapter, with its own capability matrix; do not silently map unlike events to the same certainty level.
- **Phase 3:** Enforceable policies and per-project skill configuration after pre-action hooks are verified; show a diff preview for config changes.
- **Phase 4:** Optional team sync, shared incident links, and retention administration after a clear privacy and tenancy design.
- **Phase 5:** Comparison of runs, regression detection, and a visual time-lapse export. Export is secondary to the inspectable live debugger.

## Cross-sprint quality bars

- Data provenance: every normalized event retains its source and raw record reference.
- Honest coverage: direct, correlated, and unknown are distinct labels in data and UI.
- Privacy: metadata-only by default; full payload capture requires explicit opt-in.
- Performance: event ingest must not block Codex tool execution; UI can fall behind without losing stored events.
- Accessibility: scene is never the only path to information; equivalent timeline/table is always available.
- Compatibility: adapter-specific behavior stays behind a contract and is tested against pinned runtime versions.

## Milestone review questions

After Sprint 0: Is Codex instrumentation rich enough for a credible debugger, and which connection mode is supportable? After Sprint 3: Can developers trace a failure to evidence without animation? After Sprint 5: Does animation speed diagnosis or simply look engaging? These questions decide whether to continue with the proposed architecture or change course.
