# Security and privacy

LTO OR/CR documents may contain personal and vehicle-related information. This
project must be handled as a sensitive-document automation, even when the AI
model runs locally.

## Public portfolio rules

- Do not commit original OR/CR images, filenames, plate numbers, or personal data.
- Use synthetic/redacted fixtures and screenshots only.
- Keep database credentials, n8n credentials, and local paths out of Git.
- Restrict document folders and PostgreSQL access to authorized local users.
- Review generated Excel reports before sharing because they may reproduce extracted data.

## Known gaps

The exports and migrations do not document access control, encryption at rest,
document-retention rules, malware scanning, or a privacy-compliant deletion
process. Do not represent this prototype as suitable for processing real public
documents without those controls.
