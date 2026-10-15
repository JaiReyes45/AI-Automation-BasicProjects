# Telegram and tunnel setup

For a fresh clone, start with [setup.md](setup.md). The notes below include the
historical deployment evidence; the current engine/intake count is 42 tests.
Migration 006 and the later memory/discovery fixes are deployed locally.

Current verified state: 27 unit/intake tests PASS; rollback/concurrency and native smoke tests PASS; runtime 00–09 active and 10–12 manual. The custom node is persisted/reloaded, tunnel renewed privately and local/public invalid-auth checks return 403. Initial live greeting/discovery replies are confirmed sent. Full estimate/consent/contact/handoff remains pending. The following steps are maintenance/setup guidance, not claims that pending journey tests passed.

1. Confirm the original local stack and host port. The staged override defaults to n8n host port `5686`; verify the actual mapping. Confirm PostgreSQL access and that n8n can reach `http://ollama:11434/api/generate` with `qwen2.5:3b` available. Do not expose PostgreSQL or Ollama through the tunnel.
2. Live 001/002 are preserved and 003/004/005 are applied; catalog counts are 25 services, 4 packages, 10 adjustments. Follow the [database guide](database-guide.md) for future environments; do not rerun 002.
3. Use a dedicated demo bot created through Telegram's BotFather. Store its token only in n8n credentials/private configuration. Never place it in docs, workflow JSON, commands recorded for a demo, or screenshots.
4. Install the custom intake node from reviewed source as described below, then regenerate/import all 00–12 exports. Rebind each Execute Workflow node to its imported target if IDs change. Bind PostgreSQL credentials to database nodes, the encrypted Telegram credential to custom intake 01, and the existing native Telegram send node in 09. Confirm authenticated editor access before tunneling. The current installer recognizes specific node type names; the parent must verify credential binding for the custom type before use.
5. For a temporary demo tunnel, after verifying the host port, run `cloudflared tunnel --url http://localhost:5686` locally. The generated HTTPS hostname is temporary and changes on restart; the process must remain running. Quick Tunnels are development/testing infrastructure, with no uptime guarantee. [Cloudflare setup](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).
6. Set n8n's externally advertised webhook base to that HTTPS address with a trailing slash, then restart/recreate the relevant service using the actual stack configuration. The staged override uses `WEBHOOK_URL`; current n8n documentation uses `N8N_WEBHOOK_URL` from 2.35.0 onward. Choose the variable supported by the installed version. Configure proxy hops for the real proxy chain (one hop in the documented simple example). [n8n reverse-proxy configuration](https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/configuration-examples/configure-webhook-urls-with-reverse-proxy.md).
7. When the parent is ready for the controlled live check, publish the intended demo ingress and workers 01, 00 and 09, then restart the running n8n service after CLI publication. Verify node loading, schedules and webhook registration after restart; CLI success alone is not proof of active runtime state. Confirm the webhook points to the current HTTPS hostname privately. Telegram allows one webhook per bot; test and production registration replace each other. Use separate bots if both are needed. [Telegram trigger guidance](https://docs.n8n.io/integrations/builtin/trigger-nodes/n8n-nodes-base.telegramtrigger/common-issues).
8. Start the bot in a private chat. Verify `/start`, one durable inbox receipt and one confirmed reply before natural-language testing. Wait for `/consent` acknowledgement before submitting synthetic contact details.

The owner destination is configured privately from the sole existing test customer. A synthetic setup message has Telegram delivery confirmation and created no lead; it was not correlated with a real handoff ticket. The full ticket-to-owner journey remains pending. Never print or seed the actual owner ID.

## Source installation and publish/restart

Verified installation/reload: `/home/node/.n8n/custom/P06TelegramIntake.node.js` on the persisted n8n volume. The steps below describe maintenance; installation and reload are complete for the current runtime. Confirm deployment separately after the final revised engine is installed.

1. Use the reviewed custom-node source and the build requirements compatible with the installed n8n version. Confirm the node uses encrypted credentials rather than embedded tokens and specifies `responseMode: lastNode`.
2. Install/update that source at `/home/node/.n8n/custom/P06TelegramIntake.node.js` on the persisted n8n volume, with the required runtime access. Include it in the actual container configuration so a restart/recreation retains it. Do not treat a temporary copy into a container as a completed source installation.
3. Restart n8n to load the installed node. Verify that the custom type resolves and its credential is bound privately, then regenerate/import the workflow exports. Check that intake waits for `accept_update`, with failure and duplicate paths covered.
4. The [installer](../scripts/install_workflows.py) copies the custom node to the persisted n8n directory, stages bound workflow files in private `.runtime/`, imports them and can publish internal 02–08, adding 00/01/09 for full publication. It does not restart the service. After installation/publication, restart n8n and verify node loading and runtime state. Latest local deployment is verified; a new clone requires its own checks.

Keep the bot token, any webhook authentication secret/header value, complete live webhook URL/path, and bound workflow files private. Do not log or screenshot registration responses containing these values. Local/public invalid-authentication rejection (403) is verified; a secret URL or encryption at rest alone is not evidence of authenticated intake.

Keep the editor authenticated and limit exposed routes appropriately. An interactive email-login challenge on the webhook path prevents Telegram's non-interactive requests. Private `.runtime/` files, live URLs and credential screens do not belong in public artifacts. After a temporary demonstration, disable its triggers/workers as appropriate and stop its tunnel; preserve stored evidence and the inactive learning workflow.

Teaching note: the tunnel supplies public HTTPS reachability. It does not approve requests, store business state, or prove that a message reached its recipient.

Current tunnel status: renewed privately after the old hostname's DNS failure; initial live Telegram processing/delivery verified. Keep replacement URLs, secret/header values and registration responses private.

A temporary standard native Webhook (`lastNode`) plus PostgreSQL probe passed: HTTP 200 took about 1.1 seconds after `pg_sleep(1)`, and database failure returned HTTP 500. The probe was unpublished afterward. This verifies the standard `lastNode` mechanism, not an authenticated custom-intake database-outage scenario.
