# Gmail Intake Adapter Setup

Workflow `11 - Gmail Lead Adapter Template` shows how Gmail can become another
input channel without duplicating the lead-processing logic.

## Safe design

- The public export is inactive and contains no OAuth credential or trigger state.
- Real messages enter the workflow when they are unread and carry the
  `CRM-LEAD` label; no special subject prefix is required.
- Clients can write ordinary natural-language inquiries. Local Ollama extraction
  converts the sender, company, role, budget, and request into the intake shape.
- The adapter sets `source` to `gmail` and calls Workflow 00 without duplicating
  the validation, scoring, or CRM logic.
- PostgreSQL remains the system of record; Gmail is only an intake channel.
- Successful messages are marked read, labeled `CRM-PROCESSED`, and have
  `CRM-LEAD` removed. Failed or incomplete messages remain unread, receive
  `CRM-REVIEW`, and also have `CRM-LEAD` removed.

## Configuration in the n8n browser UI

1. Create a Google Cloud OAuth client intended only for this local n8n test.
2. Add n8n's displayed OAuth callback URL to the client's redirect URLs.
3. In n8n **Credentials**, create a Gmail OAuth2 credential and complete the
   browser authorization. Never paste the token into workflow JSON.
4. In Gmail, create the labels `CRM-LEAD`, `CRM-PROCESSED`, and `CRM-REVIEW`.
5. Open the Gmail Trigger, select the credential, and confirm the search filter
   is `label:CRM-LEAD is:unread`.
6. Configure the Gmail action nodes with the matching label IDs.
7. Run the manual synthetic branch first. It exercises the complete business
   path but deliberately skips changing Gmail.
8. Activate the workflow, label one unread test inquiry `CRM-LEAD`, and wait for
   the one-minute polling interval.

## Expected email body

The sender writes a normal inquiry, for example: “I’m Maria Santos, Operations
Director at Northstar Retail Systems. We have around 50 employees and want to
automate invoice approvals. Our budget is about PHP 150,000.” The sender address,
subject, signature, and body are used as evidence; missing facts remain null or
use documented deterministic fallbacks.

## Verification checklist

- The Gmail message ID is retained for traceability.
- Reprocessing the same submission ID produces an idempotent repeat.
- Missing sender details or insufficient message text requests review.
- Successful CRM sync applies `CRM-PROCESSED`; failure applies `CRM-REVIEW`.
- No real email, contact, or customer content appears in screenshots or exports.

The natural-language synthetic path is verified end to end through HubSpot and
PostgreSQL. The public export intentionally requires the reader to supply their
own OAuth credential and Gmail label IDs.
