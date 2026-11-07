# Build pilot evidence

The bounded pilot uses a fresh disposable copy of the recovered CRM package and a tiny lead-validation adapter. It runs one model task, verifies the actual process exit, records a before/after source review, and leaves the release milestone incomplete until an explicit owner decision. It never connects to HubSpot.

Commands:

```powershell
npm.cmd run pilot:build -- --synthetic
npm.cmd run pilot:build -- --real
```

Real mode uses the advertised `gpt-6-luna` model; set `ACC_PILOT_MODEL` to another model advertised by your installed runtime. The first attempt used the configured `gpt-6.1-sol` default, absent from the CLI catalog, and failed without a change. After read-only diagnosis, one corrected attempt succeeded.

Actual real evidence: `.scratch/build-pilot/real-1794047787595/result.json` and `review.txt`. The missing/whitespace email changed from a generic error to `Email is required`; the configured Node verifier exited zero. Live/replay scenes matched. Owner acceptance remains pending; no release or public deployment occurred.

Runtime-reported cumulative usage: 106,444 input, 579 output, 83,968 cached tokens. These are measured runtime counts, not a prediction or hard limit. Installed global instructions/skills can impose substantial context overhead even for small tasks. Canvas animation and replay make no model calls.

Synthetic tests exercise explicit owner acceptance after failed-then-corrected checks; record-only mode never invents acceptance. Scheduler cancellation/dependency tests cover stopped downstream work.
