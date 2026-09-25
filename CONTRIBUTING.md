# Contributing

This repository is a public automation portfolio. Contributions should make a
project easier to review, reproduce, and operate safely.

## Before you start

- Use synthetic data only. Do not add real customer, employee, or credential data.
- Copy `.env.example` to a local `.env`; do not commit `.env` files or n8n credentials.
- Run Docker Compose commands from the repository root and validate with `docker compose config --quiet` before starting the stack.
- Do not use `docker compose down -v` for a demo environment unless the volume deletion is intentional.

## Adding or extending a project

Place each project in `projects/NN-short-project-name/`. Its README should
clearly state:

1. Current status: prototype, built, verified, or in progress.
2. The business problem and expected outcome.
3. Architecture, tools, and integrations.
4. Setup or review instructions.
5. Validation evidence, known limitations, and next steps.

Keep project-specific migrations, fixtures, diagrams, screenshots, and source
files with that project. Workflow exports must be safe to publish and contain
no credentials. Put shared-Compose workflow exports in the matching directory
under `workflows/`.

## Before opening a pull request

- Check formatting with `git diff --check`.
- Run the project’s documented tests or validation commands.
- Update the relevant README and demo evidence when behavior changes.
- Confirm status claims are factual and distinguish planned work from verified work.

The pull request template contains the same review checklist.
