# Business Policies

These are the approved Phase 1 defaults. They are configuration, not prompt
instructions, and will later be represented as database records or validated
application settings.

## Estimate safety

- Minimum AI confidence for an automated interpretation: `0.75`.
- Maximum automatic estimate total: `PHP 85,000`.
- Every estimate is preliminary and non-binding.
- Third-party subscriptions, hosting, domains, paid APIs, premium CRM
  features, AI usage, and messaging charges are excluded unless explicitly
  listed.
- Discounts require human approval.
- Data migration requires human quotation.
- Sensitive or regulated-data projects require human review.
- Final quotations and contracts require human review.

Required disclaimer:

> This is a preliminary, non-binding estimate based on the information currently available. The final quotation will be confirmed after reviewing the complete workflow requirements, integrations, and access requirements.

## Lead qualification

| Score | Status | Default action |
|---:|---|---|
| 75–100 | HOT | Save lead and create human follow-up task |
| 45–74 | WARM | Save lead and invite consultation |
| 0–44 | COLD | Save inquiry and continue helpful guidance |

The score is deterministic. AI may provide extracted facts and confidence,
but it may not directly assign the final status.

## Mandatory human handoff

Create a handoff ticket when the customer requests a person, confidence is
below `0.75`, no approved service matches, a discount or final quote is
requested, the project is sensitive or regulated, requirements conflict, the
customer is dissatisfied, the automatic-estimate ceiling is exceeded, or a
dependency repeatedly fails.

## Consent and privacy

- Ask for consent before collecting contact information for follow-up.
- Do not request passwords, API keys, payment-card data, or government IDs.
- Store only information needed for the pre-sales process.
- Honor `/privacy` and future deletion requests through a human-reviewed path.
- Use synthetic portfolio data in fixtures, demonstrations, and public exports.
