# Recovering a local Telegram demo

## Observed outage: 2026-11-01 (Asia/Manila)

The local n8n health endpoint returned 200 and the PostgreSQL/Ollama containers
were healthy. The configured public tunnel hostname failed DNS resolution and
no cloudflared process was running. Real Telegram customer, `/services`, and
`/rates` messages remained unanswered. The model was not the failing boundary.

The new launcher starts a temporary Cloudflare tunnel and supplies its generated
address to `refresh_tunnel.py`. The helper checks public health before editing
only `WEBHOOK_URL`, backs up `.env` privately, validates Compose, and recreates
n8n with its existing volumes and encryption key. Active intake registration then
uses the new URL; pending Telegram updates are not deliberately discarded.

## Start a supervised demo

The documented Docker stack must already be running, cloudflared must be
installed on Windows, and the repository must be accessible through Ubuntu WSL.
From PowerShell, invoke the launcher using its actual local/UNC path:

```powershell
& '<checkout>\projects\06-ai-telegram-presales-assistant\scripts\start_demo.ps1' -LinuxProjectPath '/path/to/checkout/projects/06-ai-telegram-presales-assistant'
```

Keep that supervisor open during the demo. If cloudflared exits, the supervisor
creates a new tunnel and refreshes the address automatically. Ctrl+C ends its
owned tunnel. Logs stay in a unique local temporary directory; do not publish
them or their generated hostname. Do not run multiple supervisors for the same bot.

This exposes port 5686 through Cloudflare, including the n8n editor. Maintain
authenticated editor access. It does not provide permanent hosting or a stable
hostname, and it does not run automatically at Windows login. If the computer,
Docker, supervisor, internet connection, or Cloudflare service is unavailable,
Telegram cannot reach the webhook and the bot cannot send an immediate outage
notice through that same disconnected path. Reliable continuous availability
requires a continuously reachable deployment.

## Verify recovery

Run `scripts/check_deployment.py` and `scripts/test_webhook_auth.py` in Ubuntu:
local/public health must pass and unauthenticated requests must return 403.
Then send `/services`, `/rates`, and a fictional customer inquiry in Telegram.
Confirm the messages actually arrive and produce replies; container health alone
does not verify Telegram delivery.

## Owner notifications in the same test chat

Migration 007 retains the review ticket and customer acknowledgement, but skips
the internal owner summary when the owner destination equals the originating
customer chat. A separately configured owner still receives the internal notice.
The isolated-schema test checks both routes and rolls back all synthetic records.
The former internal messages in Telegram history are not deleted.

The user explicitly approved restoration of the public tunnel on 2026-11-01.
The tunnel was restarted and the new address passed public health validation.
n8n was recreated with existing volumes/credentials. Local/public health returned
200 and unauthenticated local/public webhook requests returned 403. Queued
Telegram messages resumed: a restaurant inquiry received a daily-volume question,
and `/services` and `/rates` returned visible replies. The queued inquiry and
following replies took roughly 70 seconds while local AI processing completed;
this is recovery evidence, not a normal steady-state response-time benchmark.

The tunnel is currently a background cloudflared process. The supervisor launcher
is prepared and syntax-checked for future demos; it has not been installed as an
automatic Windows startup task. A permanent address and continuous hosting are
not configured. No repository commit or push was performed for this repair.
