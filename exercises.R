# =============================================================================
# retail-customer-segmentation-data-prep
# Data Preparation practice set: from RAW customer export to a
# segmentation-ready dataset (Gold / Silver / Bronze retail segments)
# -----------------------------------------------------------------------------
# Style: long exercise with a lot of small manipulations (a), b), c), ...).
# Solutions are in solutions.R - try the exercises first!
#
# Required packages: readr, dplyr, stringr
#   install.packages(c("readr", "dplyr", "stringr"))
# =============================================================================

library(readr)
library(dplyr)
library(stringr)

# -----------------------------------------------------------------------------
# Context
# -----------------------------------------------------------------------------
# The marketing team of a premium retail brand wants to segment its customers
# (Gold / Silver / Bronze) before the next campaign. You receive a raw export
# (data/customers_raw.csv) where every field is messy. Your job: clean it,
# build the segmentation features, and export a tidy dataset.
#
# Analysis date: the team runs the segmentation on 2025-09-30.

# -----------------------------------------------------------------------------
# Exercise 3.1 - Import & profile
# -----------------------------------------------------------------------------
# a) Import data/customers_raw.csv with read_csv() so that EVERY column is
#    read as character and empty fields become NA:
#      col_types = cols(.default = col_character())
#    (read_csv already turns "" into NA by default). Store as customers.
# b) Profile the data: how many rows? Which columns contain missing values,
#    and how many NAs does each have? (use is.na() + colSums())

# -----------------------------------------------------------------------------
# Exercise 3.2 - Clean the text fields
# -----------------------------------------------------------------------------
# c) Clean the name column:
#      - remove honorific prefixes ("Mr.", "Mrs.", "Ms.", "Dr.", "DR.")
#      - squash repeated whitespace with str_squish()
#      - normalise case with str_to_title()
#    Store the result in a new column name_clean.
# d) Clean the phone column:
#      - keep only digits with str_remove_all(phone, "[^0-9]") ("" -> NA)
#      - store as phone_digits
#      - normalise FRENCH numbers to national format: "0033..." -> "0...",
#        and "33..." (11 digits) -> "0..." - only when the cleaned country
#        is "FR". Store as phone_national.
#      - validate: a phone is valid if it has between 9 and 15 digits.
#        Store as phone_valid (logical).
# e) Clean the email column:
#      - pattern for a plausible email: "^[^@]+@[^@]+\\.[^@]+$"
#      - create email_status with values "valid", "invalid" or "missing".
# f) Clean the country column: normalise every value to an ISO2 code
#    (e.g. "France" -> "FR", "Germany" -> "DE", "UK" -> "GB", "USA" -> "US").
#    Store as country_code. How many customers per country?

# -----------------------------------------------------------------------------
# Exercise 3.3 - Dates & numerics
# -----------------------------------------------------------------------------
# g) join_date and last_purchase_date appear in THREE formats:
#      "2023-04-12"  (ISO,     %Y-%m-%d)
#      "12/04/2023"  (DMY,     %d/%m/%Y)
#      "04-12-2023"  (MDY,     %m-%d-%Y)
#    Write a small helper parse_date_multi(x) that converts the column to Date.
#    WARNING: as.Date(x, format) is LENIENT - it can half-match a string and
#    roll the leftovers into the date. Validate the WHOLE string with an
#    anchored regex FIRST, then parse only the values that matched.
#    Apply the helper to both date columns.
# h) orders: convert to integer with as.integer(). Keep NA where missing.
# i) total_spend: convert to numeric WITHOUT losing data:
#      - remove "$", "USD", commas and spaces
#      - "(45,000)" style parentheses become a negative sign
#      - "n/a" stays NA deliberately
#    Store as spend_num.

# -----------------------------------------------------------------------------
# Exercise 3.4 - Features, segmentation & export
# -----------------------------------------------------------------------------
# j) Create recency_days = analysis_date - last_purchase_date
#    (analysis_date <- as.Date("2025-09-30")). Interpret the result.
# k) Create the segment column with dplyr::case_when():
#      - "Gold"   if spend_num >= 3000
#      - "Silver" if spend_num >= 800
#      - "Bronze" otherwise (spend < 800)
#      - keep NA spend as NA (unclassified).
# l) Build a frequency table of the segments. Which segment is the largest?
# m) Build a small summary per segment with dplyr::group_by() + summarise():
#    number of customers, mean spend, mean orders, mean recency_days.
# n) Data quality: how many customers have a missing phone, an invalid email,
#    a missing spend, a NEGATIVE spend, or a zero spend?
# o) Write the final tidy dataset to data/customers_clean.csv with write_csv().
