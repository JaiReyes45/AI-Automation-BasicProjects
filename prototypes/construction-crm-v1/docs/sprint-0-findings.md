# Sprint 0 — observed integration findings

Environment: Windows; Codex CLI 0.155.1; Node 22.16.0. Protocol schemas generated locally into ignored `.scratch/schema`. Reference: [official app-server documentation](https://learn.chatgpt.com/docs/app-server).

## Results

| Capability | Evidence | Status |
|---|---|---|
| Client-owned stdio session | initialize, thread/start, thread/started | Verified live |
| Turn lifecycle | turn/started, turn/completed | Verified live |
| Tool start/end | item/started and item/completed, commandExecution | Verified live |
| Command failure | commandExecution exitCode 7 | Verified live |
| File edit | probe.txt contained hello after the run | Verified file result; write happened through shell, so no direct fileChange event |
| Approval request | production CLI received command approval requests and declined them | Verified live |
| Skill invocation | prompt requested reading a local SKILL.md fixture | No direct skill-invocation evidence; do not infer activation |
| Inventory locations | live skills/list returned 47 skills across user/system scopes, with paths under skills, .system, engineering and productivity roots | Discovery API verified; dashboard inventory management remains Sprint 2 |
| Cancellation | turn/interrupt request implemented | Not verified against a live interrupted model turn |
| Attach existing desktop session | no tested attachment to the user's desktop transport | Unsupported in this release; client-owned launch chosen |

The generated 0.155.1 schema expects `workspace-write` for thread/start sandbox; the public example used `workspaceWrite`. Local protocol wins. The explicit `gpt-6.1-sol` probe failed with model_not_found for this ChatGPT account; the configured default completed the probe. The recorder does not hard-code a model.

The sanitized method/type/status transcript is checked into `fixtures/codex-0.155.1-probe.json`. It contains no task text, output deltas, credentials, or private reasoning. Probe file read, file write and exit-code-7 command completed in `.scratch/probe-project`. A separate production CLI run verified persistence and approval-decline handling; its tool attempts were declined and its turn completed normally.

## Decisions

Use client-owned app-server launch for MVP, metadata-only capture, and explicit capability labels. A requested skill remains requested unless a runtime signal proves more. Tool-to-skill causality is unknown. Prefer version-specific fixtures over assumptions from current online examples.

## Prototype flow

The intended interaction is run list → select live run → filter failed tool → inspect source IDs and exit code → jump to surrounding events. See `docs/prototype.html` for a throwaway clickable flow; its events are synthetic and it is not connected to the recorder.
