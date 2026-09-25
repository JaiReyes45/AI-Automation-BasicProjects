# Testing and evidence

## Current evidence

The repository contains two public-safe screenshots:

- [Workflow canvas](../screenshots/workflow.png)
- [Chat demo](../screenshots/demo.png)

These demonstrate that the workflow and a local chat interaction were created.
They do not replace repeatable functional or safety testing.

## Suggested repeatable checks

| Check | Expected outcome |
| --- | --- |
| Basic prompt | A response is returned through n8n. |
| Ollama stopped | A clear, non-sensitive failure is visible. |
| Empty prompt | The workflow behavior is recorded and assessed. |
| Restart | The workflow reconnects after the local model is available. |

No controlled-test execution log is currently recorded. Mark results as
verified only after performing and recording those checks.
