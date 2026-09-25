# Security and privacy

Expense descriptions and amounts can be personal financial data. Use synthetic
examples in the repository and avoid sending real expenses through a portfolio
demo.

## Rules

- Keep PostgreSQL passwords and n8n credentials in local `.env` or n8n credential storage only.
- Do not commit webhook URLs intended for exposed environments.
- Run the local stack behind localhost bindings unless access has been reviewed.
- Sanitize screenshots and database exports before publishing them.

## Known gaps

The exported workflow does not document authentication for the webhook,
encryption requirements, retention policy, authorization model, or a financial
audit trail. It is a learning workflow, not an accounting system.
