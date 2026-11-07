# Operator recovery

Stop and inspect a failed job before replaying it. **Replay with reconciliation** accepts only a current dead-letter job/version and records the owner decision. Changed or repeated requests conflict. It never resets a provider intent that might already have created an object.

If a worker dies, its 60-second lease expires. The next worker uses a new lease token; the stale worker cannot finish the job. It reconciles uncertain remote effects. If no authoritative object can be found after an uncertain write, the job requires review rather than another blind create.

A local restart expires pending approvals and marks unfinished runtime tasks failed. Queued prompts are not saved. Recommission work explicitly after inspecting Git and the saved evidence. Live/replay scenes reconstruct recorded state; reconnect can reset from a retained checkpoint.

For a lost or expired hosted owner token, use the private management profile with the provisioner credential:

```sh
docker compose --env-file deploy/.env -f deploy/compose.yaml --profile manage run --rm manage node services/operations/src/manage.mjs recover-owner --output /operator-secrets/owner_token_recovered
```

This operator-invoked command revokes old owner tokens, creates a new 30-day token in a create-only private file and audits recovery. Update the local `OPERATIONS_OWNER_TOKEN` and restart that local server. Build mode remains available while hosted access is disconnected. Do not expose a public token-recovery endpoint.

Never regenerate a deployment encryption key during restart. Restore the original key from its private backup. Without it, encrypted provider credentials cannot be recovered; rotate/reconnect those provider credentials deliberately. Database/runtime password rotation requires the matching database login and private URL files to be changed together, followed by service restarts. The initial provision command refuses existing runtime logins.

Back up before migrations. Restore a logical backup into a new database and validate migrations, receipt privacy and owner access there before a controlled cutover. The disposable test harness performs this restore check without touching a live URL.
