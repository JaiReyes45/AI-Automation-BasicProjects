# Testing and evidence

## Current repository evidence

- [OR/CR processing workflow](../workflows/lto-orcr-processing.json)
- [Excel reporting workflow](../workflows/lto-excel-registration-report.json)
- [Registrations schema](../database/001_create_registrations.sql)
- [Manual-review schema](../database/002_create_manual_reviews.sql)

These artifacts demonstrate design and implementation. No dated controlled run
with synthetic documents is recorded yet.

## Suggested test matrix

| Test | Expected outcome |
| --- | --- |
| Valid synthetic OR/CR image | One completed registration and report row. |
| Same image twice | Second processing is identified as duplicate. |
| Missing plate or fee | Manual-review row with a validation reason. |
| Negative calculated fee | Database constraint prevents invalid persistence. |
| Model unavailable | Safe error is captured without a completed registration. |
| Excel write unavailable | Failure is recorded and no misleading completion claim is made. |

Record the test date, synthetic fixture identity, execution ID, database result,
and report result before marking a test verified.
