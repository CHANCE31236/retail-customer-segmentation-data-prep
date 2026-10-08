# Run from the repository root: Rscript --vanilla tests/smoke.R
options(warn = 2)
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr) })

check_pipeline <- function() {
  repo <- normalizePath(".", winslash = "/")
  scratch <- tempfile("retail-smoke-")
  dir.create(file.path(scratch, "data"), recursive = TRUE)
  stopifnot(file.copy("data/customers_raw.csv", file.path(scratch, "data")))
  on.exit(setwd(repo), add = TRUE)
  setwd(scratch)
  source(file.path(repo, "solutions.R"), local = TRUE)
  stopifnot(nrow(customers) == 24L, nrow(clean) == 24L,
            identical(clean$phone_national[1], "0612345678"),
            identical(clean$orders[1], "12"),
            sum(is.na(clean$phone_national)) == 7L,
            sum(clean$email_status == "invalid") == 2L,
            sum(is.na(clean$spend_num)) == 1L,
            clean$spend_num[10] == -250, is.na(clean$segment[20]),
            sum(clean$segment == "Gold", na.rm = TRUE) == 6L,
            sum(clean$segment == "Silver", na.rm = TRUE) == 10L,
            sum(clean$segment == "Bronze", na.rm = TRUE) == 7L,
            !anyNA(clean$join_date), !anyNA(clean$last_purchase_date))
  parsed <- parse_date_multi(c("2023-04-12", "12/04/2023", "04-12-2023", "n/a", NA))
  stopifnot(identical(parsed[1:3], rep(as.Date("2023-04-12"), 3)),
            all(is.na(parsed[4:5])))

  # Country names must receive the same phone normalization as ISO2 codes.
  raw <- read_csv("data/customers_raw.csv", col_types = cols(.default = col_character()))
  raw$country[2] <- "france"
  raw$phone[2] <- "+33 6 12 34 56 78"
  write_csv(raw, "data/customers_raw.csv")
  source(file.path(repo, "solutions.R"), local = TRUE)
  stopifnot(clean$country_code[2] == "FR", clean$phone_national[2] == "0612345678")
  cat("Retail data preparation checks passed.\n")
}
check_pipeline()
