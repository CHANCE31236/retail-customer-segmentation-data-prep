# retail-customer-segmentation-data-prep

A data preparation pipeline in R: a messy CRM customer export goes in, a tidy
segmentation-ready dataset comes out.

The repository is written as a university *Data Preparation* lab session —
step-by-step exercises with hints, plus a fully commented solution — and the
same pipeline doubles as a worked example of the
*profile → clean → transform → segment → export* workflow.

## What the pipeline covers

- Importing a CSV with every column as character and empty fields as `NA`
- Profiling missing values before changing anything
- Regex cleaning: honorifics, whitespace, phone digits, email validation,
  country codes
- Multi-format date parsing with a reusable base-R helper
- Messy currency to numeric without losing values (symbols, separators,
  negatives written as parentheses)
- Feature engineering: recency / frequency / monetary
- Business-rule segmentation with `case_when()` and a per-segment summary
- A data-quality audit and a clean CSV export with a round-trip check
- A written data preparation specification in `docs/`

## Files

| File | Purpose |
|------|---------|
| `exercises.R` | The exercises with hints |
| `solutions.R` | Commented solutions with expected outputs |
| `data/customers_raw.csv` | The messy CRM export (24 customers) |
| `data/customers_clean.csv` | The tidy output, committed as a reference |
| `docs/data-preparation-spec.md` | The specification: rules, schema, QA checks |

## Running it

```r
install.packages(c("readr", "dplyr", "stringr"))   # once
source("solutions.R")
```

R 4.0 or newer. The dataset is synthetic and the analysis date is fixed at
`2025-09-30`, so the output is reproducible.

## Segmentation rule

| Segment | Rule (total spend) |
|---|---|
| Gold | ≥ 3000 |
| Silver | ≥ 800 |
| Bronze | < 800 |
| — | missing spend stays `NA` and is flagged for CRM follow-up |

CSV files do not carry column types. The round-trip import explicitly treats
phone numbers and other identifiers as character data, preserving leading zeroes.
French phone normalization accepts both `FR` and `France`.

The full rule set, the column-by-column schema and the QA checks are in
[docs/data-preparation-spec.md](docs/data-preparation-spec.md).

## Validation

Run from the repository root:

```bash
Rscript --vanilla tests/smoke.R
```

GitHub Actions runs the same checks on every pull request. The exercise file
retains its practice tasks; automated checks run the completed solutions.
To display each solution step interactively, use `source("solutions.R", echo = TRUE)`.

## License

MIT — see [LICENSE](LICENSE).
