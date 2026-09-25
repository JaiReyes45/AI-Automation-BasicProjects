# Security policy

## Keep sensitive data out of this repository

Do not commit API keys, passwords, n8n credential exports, `.env` files,
database backups, real customer data, or screenshots containing personal data.
Use synthetic fixtures and local test credentials for every public example.

## Reporting a vulnerability

Do not disclose a security issue, exposed secret, or sensitive data in a public
GitHub issue. Use GitHub's private vulnerability-reporting feature when it is
available for this repository, or contact the repository owner privately via
their GitHub profile with:

- a concise description of the issue;
- affected file or component;
- reproduction steps; and
- suggested mitigation, if known.

If a secret is accidentally committed, revoke or rotate it immediately. Removing
the file alone does not make the secret safe because Git history may contain it.
