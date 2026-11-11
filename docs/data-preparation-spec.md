# Customer Segmentation - Data Preparation Specification

| Field | Value |
|---|---|
| Document owner | Data team (Data Preparation) |
| Status | Draft v1.0 |
| Last updated | 2025-09-30 |
| Related Jira | DATA-117 (Prepare clean customer table for Gold/Silver/Bronze segmentation) |
| Analysis date | 2025-09-30 |

## 1. Objective

Deliver a single, clean, customer-level dataset that the marketing team can use
to segment the premium retail customer base into **Gold / Silver / Bronze**
before the Q4 campaign.

## 2. Scope

- **In scope**: customer identity fields (name, phone, email, country),
  lifecycle fields (join date, last purchase date), behavioural fields
  (number of orders, total spend).
- **Out of scope**: order-line level data, product-level data, campaign
  response data, PII anonymisation (handled downstream).

## 3. Data source

| Source | Format | Path | Notes |
|---|---|---|---|
| CRM raw export | CSV (messy) | `data/customers_raw.csv` | 24 records; all fields read as character |

## 4. Cleaning rules

### 4.1 Names
- Remove honorific prefixes (`Mr.`, `Mrs.`, `Ms.`, `Dr.`, `DR.`).
- Squash repeated whitespace; normalise to title case.
- Result column: `name_clean`.

### 4.2 Phone numbers
- Strip every non-digit character; empty value becomes `NA`.
- French numbers (`country = FR`): `0033...` or `33...` (11 digits) prefixed
  to national `0...` format.
- Validity: 9-15 digits after normalisation; otherwise `invalid`.
- Missing phone stays `NA` (do not impute).

### 4.3 Email
- Plausibility check: `^[^@]+@[^@]+\.[^@]+$` -> `valid` / `invalid` / `missing`.
- Invalid emails are flagged, not dropped.

### 4.4 Country
- Normalise every value to ISO2 code (`France` -> `FR`, `UK` -> `GB`, ...).
- Unknown values are kept in uppercase, never silently mapped.

### 4.5 Dates
- Three accepted formats, resolved in order: `%Y-%m-%d`, `%d/%m/%Y`, `%m-%d-%Y`.
- Convention documented: slashes are interpreted as **DD/MM/YYYY**, dashed
  two-digit-month dates as **MM-DD-YYYY**.
- All unparsable dates become `NA` and are reported.

### 4.6 Numerics
- `total_spend`: remove `$`, `USD`, commas, spaces; parentheses denote a
  negative amount (`(45,000)` -> `-45000`); `n/a` is a deliberate `NA`.
- `orders`: integer; empty stays `NA`.

## 5. Transformation rules

| Feature | Definition |
|---|---|
| `recency_days` | `analysis_date - last_purchase_date` (analysis date = 2025-09-30) |
| `segment` | Gold: spend >= 3000; Silver: spend >= 800; Bronze: spend < 800; missing spend: unclassified (`NA`) |

## 6. Output schema

| Column | Type | Example |
|---|---|---|
| customer_id | character | CUST-001 |
| name_clean | character | John Smith |
| phone_national | character | 0612345678 |
| email_status | character | valid |
| country_code | character | FR |
| join_date | Date | 2023-04-12 |
| last_purchase_date | Date | 2025-08-30 |
| orders_num | integer | 12 |
| spend_num | double | 3240.5 |
| recency_days | double | 31 |
| segment | character | Gold |

## 7. QA checks (acceptance criteria)

1. Row count is preserved: 24 in, 24 out (no silent drops).
2. No `NA` is introduced by parsing except the documented deliberate cases
   (missing phone/email/orders, `n/a` spend).
3. `colSums(is.na())` matches the expected counts in Section 4.
4. Round-trip check: `read_csv()` of the exported file reproduces 24 rows.
5. Segment frequency totals 24 (including unclassified).

## 8. Known data-quality issues (open)

- CUST-020: spend `n/a` -> unclassified segment; follow-up with CRM.
- CUST-010: negative spend (net refunds) - confirm interpretation with Finance.
- CUST-017: zero spend with 2 orders - likely churn or returns; exclude from
  campaign targeting.
