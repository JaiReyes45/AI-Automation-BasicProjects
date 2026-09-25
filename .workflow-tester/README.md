# .workflow-tester

Everything workflow-tester keeps for this repo.

| Path | What it is | Commit it? |
|---|---|---|
| `contracts/` | Materialised vendor schemas and examples, pinned to a spec version | yes |
| `cases/` | Generated cases and their index | yes |
| `tests/` | Hand-written and LLM-written tests | yes |
| `reports/` | The last run's output | no — add to .gitignore |

Generated files are committed on purpose: a pull request should show exactly
which cases changed. `workflow-tester gen --check` fails when they are stale.
