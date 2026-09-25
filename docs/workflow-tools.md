# Workflow Tools setup

This repository uses four open-source development tools for the n8n workflow
JSON stored under `projects/*/workflows/`. They are development dependencies,
not n8n community nodes: do not install them in the n8n browser UI.

## Installed tools

| Tool | Purpose | Repository command |
| --- | --- | --- |
| `workflow-lint` | Finds workflow quality and reliability issues. | `npm run workflow:lint` |
| `integration-mock` | Provides safe stand-ins for external APIs. | `npm run workflow:mock` |
| `workflow-tester` | Runs offline expression and contract tests. | `npm run workflow:test` |
| `workflow-render` | Views or exports workflow canvases as SVG/PNG. | `npm run workflow:render -- view <file>` |

## Prerequisites

Use Node.js 24 or newer. The repository pins linting and test behavior to n8n
2.34.5 in `workflow-lint.config.yaml` and `.workflow-tester/config.yaml`.

After cloning the repository, install the pinned tools with:

```bash
npm ci
```

## Lint workflow exports

Run a read-only quality check across all project workflow exports:

```bash
npm run workflow:lint
```

Do not use `workflow:lint:fix` until you review the proposed changes in Git.
The linter can apply safe mechanical fixes, but it must not silently change a
workflow's business behavior.

## Test workflow expressions

Starter test guidance is versioned in `.workflow-tester/`. Add focused tests in
`.workflow-tester/tests/`, then run:

```bash
npm run workflow:test
```

The tool runs expressions and supported Code nodes offline. It does not send
emails, call APIs, or execute credentialed nodes.

## Mock external services

Start a local mock service:

```bash
npm run workflow:mock
```

Enable only the API pack needed for a test, for example:

```bash
npx integration-mock packs enable hubspot
npx integration-mock faults set hubspot --status 503 --once
```

Because n8n runs in Docker, `127.0.0.1:8080` inside an n8n node points to the
n8n container, not this host mock. Use `integration-mock up` when testing
Docker-based n8n nodes whose URL cannot be changed, or configure a reachable
host address only in a disposable test environment. Never replace real
credentials in an active workflow without first making an inactive test copy.

Stop the mock when finished:

```bash
npm run workflow:mock:stop
```

## Render a workflow for documentation

Open a local interactive canvas:

```bash
npm run workflow:render -- view \
  projects/04-local-ai-helpdesk-ticket-triage/workflows/09-unified-helpdesk-operations.json
```

Export a public-safe image for project documentation:

```bash
npm run workflow:render -- export \
  projects/04-local-ai-helpdesk-ticket-triage/workflows/09-unified-helpdesk-operations.json \
  -o /tmp/helpdesk-workflow.svg
```

Inspect the image before committing it. Workflow JSON and rendered diagrams can
contain node labels, URLs, test data, or credential names that should not be
public.
