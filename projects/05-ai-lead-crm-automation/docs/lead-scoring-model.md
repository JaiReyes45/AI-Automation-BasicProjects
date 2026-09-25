# Lead Scoring Model — V1

## Purpose

This model ranks valid inbound leads for an SME automation consultancy serving Philippine businesses. AI may extract facts from the enquiry, but deterministic rules calculate the final score and routing result.

## Design principles

- Maximum score: 100 points.
- Missing information receives no points; it is not assumed to be negative.
- Invalid email or missing consent is a validation failure, not a low score.
- A score does not override core eligibility rules.
- Initial thresholds are test assumptions and will be calibrated with synthetic test results.

## Score factors

| Factor | Maximum | Rationale |
|---|---:|---|
| Service fit | 25 | Strongest indicator that the consultancy can solve the stated problem. |
| Budget fit | 20 | Indicates whether the likely project can support a meaningful engagement. |
| Company-size fit | 15 | The target customer is an SME with repeatable processes worth automating. |
| Purchase timeline | 15 | Measures urgency and likelihood of near-term action. |
| Decision-maker status | 10 | Leads with authority usually progress faster. |
| Business email quality | 10 | Improves contactability and reduces low-quality submissions. |
| Philippine market fit | 5 | V1 prioritizes businesses operating in the Philippines. |
| **Total** | **100** |  |

## Deterministic rules

### 1. Service fit — maximum 25

| Extracted need | Points |
|---|---:|
| CRM/lead automation, invoice/approval automation, or customer-service automation | 25 |
| Reporting, data integration, workflow automation, or document-process automation | 15 |
| General automation interest without a defined process | 5 |
| Unrelated service request | 0 |

### 2. Budget fit — maximum 20

| Stated budget in PHP | Points |
|---|---:|
| ₱150,000 or more | 20 |
| ₱100,000–₱149,999 | 15 |
| ₱50,000–₱99,999 | 10 |
| Below ₱50,000 | 3 |
| Not stated | 0 |

### 3. Company-size fit — maximum 15

| Company size | Points |
|---|---:|
| 20–200 employees | 15 |
| 10–19 or 201–500 employees | 8 |
| 1–9 or more than 500 employees | 3 |
| Not stated | 0 |

### 4. Purchase timeline — maximum 15

| Stated timeline | Points |
|---|---:|
| Within 30 days | 15 |
| 31–90 days | 10 |
| More than 90 days | 5 |
| Not stated | 0 |

### 5. Decision-maker status — maximum 10

| Role evidence | Points |
|---|---:|
| Owner, founder, CEO, director, or department head with buying authority | 10 |
| Manager, coordinator, or internal champion | 5 |
| Not stated or unclear | 0 |

### 6. Business email quality — maximum 10

| Email type | Points |
|---|---:|
| Valid company-domain email | 10 |
| Valid free-provider email | 3 |
| Invalid email | Validation failure |

### 7. Philippine market fit — maximum 5

| Location evidence | Points |
|---|---:|
| `country_code` is `PH` | 5 |
| Location not stated | 0 |
| Outside the Philippines | 0; flag for review before sales routing |

## Qualification bands

| Score | Qualification | Default action |
|---:|---|---|
| 70–100 | HOT | CRM sync, create deal when eligible, notify sales owner |
| 40–69 | WARM | CRM sync, add to manual nurture/review queue |
| 0–39 | COLD | CRM sync when valid; no automatic sales escalation |

## HOT-lead guardrails

A lead may be classified as HOT only when all of the following are true:

1. Email is valid.
2. Consent is `true`.
3. Service fit is at least 15 points.
4. Total deterministic score is at least 70.

## AI and deterministic responsibilities

| AI extracts | Workflow decides |
|---|---|
| Service category, stated budget, company size, timeline, role, location, and concise need summary | Validation status, point values, total score, qualification band, CRM routing, and manual-review requirements |

## Example

A Philippine operations director from a 48-person company requests invoice-approval automation within 30 days and states a ₱150,000 budget:

| Factor | Points |
|---|---:|
| Service fit | 25 |
| Budget fit | 20 |
| Company-size fit | 15 |
| Timeline | 15 |
| Decision-maker status | 10 |
| Business email quality | 10 |
| Philippine market fit | 5 |
| **Total** | **100 — HOT** |
