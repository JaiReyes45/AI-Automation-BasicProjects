# Workflow operation

## Primary OR/CR-processing workflow

1. A manual trigger or schedule starts processing.
2. n8n reads an OR/CR PNG and calculates its document hash.
3. PostgreSQL checks whether the same hash has already been processed.
4. A non-duplicate image is sent to the local vision model.
5. Code nodes parse extracted values and validate the result.
6. A valid extraction becomes a registration record, then contributes to the
   Excel registration report and completed-file path.
7. An invalid extraction creates a manual-review record and review-file copy.

## Extracted and calculated fields

The database schema supports plate number, vehicle type, MVUC, legal research
fee, penalty, amount paid, freelancer fee, status, and error reason.

```text
amount_paid = mvuc + legal_research_fee + penalty
freelancer_fee = PHP 250 per completed registration
```

Use anonymized or synthetic document images only. Original LTO documents can
contain personal data and should not be committed or used in public demos.
