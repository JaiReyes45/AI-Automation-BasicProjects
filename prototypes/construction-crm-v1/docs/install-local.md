# Install the private engineer's desk

Clone or extract this source repository. Use Node.js 22.13 or newer, Git and an authenticated Codex CLI. The local app has no npm dependencies.

```powershell
npm.cmd run doctor
npm.cmd test
npm.cmd start
```

Open the printed loopback URL. Select **Connect**, enter the local bearer token, and register an absolute workspace path. The local token stays in tab session storage; it is never placed in a URL. Use a dedicated project checkout when you want isolated changes.

Expand **Commission a work order**. Choose a requested crew role, an advertised runtime model and available skill packages, enter instructions, select the milestone, and start. Skills supply instructions to one runtime actor; selecting several skills does not launch several independent models. One model task runs by default. Two is the maximum and requires an explicit API decision. The admission budget counts task starts; a 20-minute deadline also applies. Model-token totals are advisory and may be unknown.

Tasks finish in verification. Inspect the concrete change and evidence, then accept the work when it meets your criteria. Configured command checks use actual exit status. A failed check or cancellation cannot complete a building. Runtime permission requests show one exact command or diff, digest and expiry. Approving an action never grants a standing session permission. Unrecognized or incomplete requests decline.

**Run diagnostics** retains the original event timeline, replay, failures, exports and bounded opt-in content capture. Prompts and model reasoning are not recorded. Project commission instructions are memory-only; re-enter them after a process restart. Pending runtime approvals expire after a restart.

For hosted Operate mode, set `OPERATIONS_BASE_URL` to the root HTTPS business service and `OPERATIONS_OWNER_TOKEN` to its private owner token in the local server environment. Restart the local server. Enter **Operate** to read sanitized lead/CRM/appointment evidence and act on reviews or stopped jobs. The remote token stays on the local server. Hosted events cannot issue coding commands.

Try the static demo with `npm.cmd run demo:site`. It contains only synthetic recorded events and requires no account, token or model. GitHub Pages can serve the repository's `demo/` page with its relative assets, but cannot run the CRM backend or coding runner.

Keep the local listener on loopback. HTTPS hosting belongs to the separate operations service. A desktop wrapper and multi-tenant accounts are outside V1.
