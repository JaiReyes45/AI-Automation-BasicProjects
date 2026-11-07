# Local runtime capability evidence

Inspected 7 November 2026: installed `codex-cli 0.155.1`. Discovery used `codex app-server --help` followed by `codex app-server generate-json-schema --experimental --out <ignored-scratch-directory>`. No model run or live escalation was needed for schema inspection.

The schema defines command and file-change approval requests with `accept`/`decline` decisions. The site supports one-action decisions only, not session acceptance or persistent policy amendments. Legacy run launches still auto-decline. A command requires a complete bounded preview and an in-project working directory. A file-change approval is available only if the same live client previously supplied the concrete change diff; requests with only an item ID, an unstable grant-root request, or an unpreviewable action are declined. Unknown request methods fail closed. Pending decisions expire after five minutes or when their client exits.

`thread/tokenUsage/updated` contains cumulative input, output and cached-input counts. The adapter records those counts when present; it does not store reasoning text. Token enforcement is not established by these notifications: budget admission/concurrency/deadline are enforceable, while an in-flight token ceiling is unavailable. Usage is unknown until measured.

Selected skills remain requested/equipped. This implementation has no tested direct skill-invocation or skill-to-tool causality signal. Source schemas are discovery evidence, not proof that every account/model emits every optional notification. Fake-runtime tests cover isolation and mapping; the later bounded real-runtime pilot is separate.
