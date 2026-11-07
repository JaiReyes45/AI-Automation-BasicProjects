# Synthetic hybrid system pilot

Evidence ID: `system-pilot-1794050043666`.
Raw report: `.scratch/system-pilot/1794050024227/evidence.json`.
Command: `npm.cmd run pilot:system -- --synthetic`.

Real boundaries: HTTP gateway, SQLite local history, disposable PostgreSQL. Provider/model transports were explicit fakes; this does not verify HubSpot or GHL account access.

- 20/20 durable receipts, submitted at one-second intervals while the local server was stopped.
- Expired first-worker lease recovered by a fresh queue instance; no automatic coding starts.
- A verified synthetic consultation coexisted with pending CRM retry.
- Reopened local dashboard snapshot matched current sanitized hosted state.
- Full replay and duplicate replay matched the authoritative hosted scene.
- 21 fake extraction calls, within the independently enforced maximum of two per enquiry.
- 19 intended contact/deal creates and one shared company; the first lead remained in CRM retry.
- 120 decorative render ticks caused zero additional model starts.
- p95 latency: 27 ms from observing the committed worker result to receiving the authenticated snapshot. This excludes provider-arrival latency and does not measure a full browser paint. The visible dashboard polls once per second.
- Operations suite: 8/8, followed by a real logical backup restored to a clean database.

Live credentialed CRM and booking gates remain pending. The isolated tests use generated credentials and clean up their Docker project after the run.


After the consolidated review fixes, the entire pilot was rerun:20 durable receipts at one-second intervals,21 synthetic extraction calls, independent booking/CRM recovery and replay checks passed. The new p95 commit-observed-to-snapshot latency was23ms. This is a repeatable local fixture-provider result, not a production throughput or browser-paint claim.
