# Local release report

Task 4 adds an explicit source allowlist package with per-file SHA-256 hashes, a safe Node/Codex/Git version doctor, and a five-project automated pilot. No registry dependencies, automatic configuration changes, public deployment or destructive cleanup are introduced.

`npm run doctor` verifies Node.js 22.13 or newer and extracts Codex/Git versions without forwarding raw command output. Availability is not account authentication or protocol capability verification.

`npm run package` writes `.scratch/release/source` and `manifest.json`. Every input is a named regular source file, never a recursive workspace copy. Private databases, `.scratch`, `.data`, credentials and user fixtures are outside the allowlist. The bundled test transport fixture is synthetic source code. Existing output is not overwritten; source symlinks and escaped paths are rejected. Hashes cover copied bytes for integrity review; this is a local source release, not a signed installer.

`npm run pilot` creates five independent Git projects in a unique OS temporary folder, makes synthetic baseline commits with per-command Git identity, and retains them with SQLite stores for inspection. It does not mutate user Git configuration. Each scenario launches the real Runner, persists via the real Store, waits for completion and reopens the database before asserting evidence. Only external model transport and inventory responses are deterministic fixtures.

| Scenario | Automated acceptance evidence |
| --- | --- |
| Success | File written; reopened persisted details show `answer.txt` as the only change |
| Failed command/test | Real Node command exits 7; tool fails while turn completes; runtime item correlation matches started tool |
| Crashed run | Transport closes without completion; persisted run and connection evidence show interrupted |
| Missing/late events | Missing start stays missing; post-completion notification is ignored; out-of-order imported event is late and duplicate is rejected |
| Manual drift/privacy | Manual edit has no fileChange evidence and stays unattributed; pre-existing dirt and `.env` excluded; opted-in content secret redacted |

Focused tests exercise package exclusion/hash/no-overwrite behavior, doctor's minimum Node boundary and safe output, and all five production-boundary scenarios. The first test run failed because these three release scripts were absent; the implemented focused suite then passed. Current command output is retained locally in `.scratch/sprints-2-5/task4-report.md`.

Human median diagnosis time is **pending**; no people have been timed and no usability improvement is claimed. See [human pilot protocol](human-pilot.md). Browser screenshot QA, real account execution, whole-branch review and final release acceptance are tracked by the coordinating task; this report does not infer those outcomes from the fixture pilot. Windows is the verified script target. SQLite's experimental warning is expected on Node 22.16.0.
