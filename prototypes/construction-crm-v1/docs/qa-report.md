# Verification record — 2026-10-31

## Automated and live evidence

- `npm.cmd test`: 33 tests passed after release review fixes. Coverage includes 1,000 out-of-order events, deduplication, restart/crash recovery, redaction, dirty Git baselines, symlink/binary/secret-file omission, runtime-ID failure correlation, authenticated HTTP, SSE cursor recovery and large-event socket backpressure, deterministic replay, terminal runs with missing tool-end evidence, transactional launch rollback, and explicit unavailable final snapshots.
- `npm.cmd run pilot`: five independent disposable Git projects passed through real Runner/Store/snapshot boundaries. External model transport is a deterministic fixture for this repeatable test. See release-report.md for scenarios.
- Live Codex 0.155.1 inventory: 47 skills, 46 available, hashes obtained from actual SKILL.md files. The unavailable item remains visible and unselectable.
- Live Codex run `0b2e4160-5ff0-40d5-9f9d-837fe71594d4`: completed, 11 events, one deliberate command failure, one final file change. `result.txt` contained `recorded`. Only the disposable `.scratch/live-project` was used. This live check is separate from the deterministic fixture pilot.
- Doctor: Node 22.16.0, Codex 0.155.1, Git 2.51.0.windows.1 available. This does not claim account credentials or arbitrary future model availability are guaranteed.
- Source package: 40 explicitly allowlisted files with hashes verified against copied bytes; no private databases, user fixtures, scratch state, or tokens bundled. The initial 37-file package was retained separately before the reviewed release was rebuilt with this report and the sprint documents.

The Astra High review found and then verified fixes for failed-launch cleanup and unavailable final snapshots. Scoped re-review is clean.

## Browser checks

The local dashboard was exercised in the in-app browser against the real loopback server. Authentication, run listing, synthetic demonstration, failure jump and correlation, actual skill discovery in the launch form, worker inspection, and replay controls were checked. Paused replay showed a running worker with computed `animationPlayState: paused` and no motion-active marker. After fixing socket backpressure, the persistent connection showed `Live · connected`.

At a 390×844 requested viewport, document client width and scroll width both measured 375 CSS pixels (the remainder is the browser scrollbar); no horizontal page overflow was observed. The run list intentionally scrolls horizontally at this width. Secondary text contrast was darkened after the design detector's warnings. A final desktop preview is saved locally in `.scratch/dashboard-desktop.png`; it is explicitly labeled synthetic.

## Model assignments actually used

| Task | Worker model | Effort |
|---|---|---|
| Inventory, snapshots, diagnostics | GPT-6.1 Sol | High |
| Foundation review | GPT-6.1 Sol | High |
| Visual debugger and revision | GPT-6.1 Terra | High |
| Release scripts, five-project pilot, packaging | GPT-6.1 Sol | Medium |
| Whole-branch release review | GPT-6 Astra | High |

The parent chat remains GPT-6.1 Sol; no tool exists to change its own model mid-turn. Worker selection implements the requested per-task changes. Product-launched Codex sessions use the local account default unless a developer explicitly supplies a model and effort; an unavailable model is not silently substituted.

## Remaining validation boundary

Human median diagnosis time and developer preference testing are pending real participants. No speedup or usability result is claimed. The human-pilot protocol is ready. Desktop-session attachment, skill-to-tool causality, interactive approval handling, cloud sync, and automatic file rollback are not supported. Snapshots show before/after interval changes as unattributed; they do not prove which concurrent actor wrote a file. Content capture is opt-in and best-effort redacted, with bounded output; metadata remains the default.
