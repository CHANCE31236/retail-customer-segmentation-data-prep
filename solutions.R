# =============================================================================
# retail-customer-segmentation-data-prep - SOLUTIONS
# -----------------------------------------------------------------------------
# Comments show the expected results. Display each step with:
#   source("solutions.R", echo = TRUE)
# Working directory must contain the data/ folder.
# =============================================================================

library(readr)
library(dplyr)
library(stringr)

# --- context ---------------------------------------------------------------
analysis_date <- as.Date("2025-09-30")   # fixed "as of" date for recency

# -----------------------------------------------------------------------------
# Exercise 3.1 - Import & profile
# -----------------------------------------------------------------------------

# a) Import everything as character, empty fields -> NA
customers <- read_csv("data/customers_raw.csv",
                      col_types = cols(.default = col_character()))
customers                     # 24 rows x 9 columns

# b) Profile: rows and missing values per column
nrow(customers)               # [1] 24
colSums(is.na(customers))
# customer_id          0
# name                 0
# phone                7
# email                1
# country              0
# join_date            0
# last_purchase_date   0
# orders               1
# total_spend          0        <- "n/a" is a LITERAL string, not yet NA;
#                                  it becomes a deliberate NA during cleaning (i)

# -----------------------------------------------------------------------------
# Exercise 3.2 - Clean the text fields
# -----------------------------------------------------------------------------

# c) Name: remove honorifics, squash whitespace, title case
customers <- customers %>%
  mutate(name_clean = str_remove_all(name, "^(Mr\\.|Mrs\\.|Ms\\.|Dr\\.|DR\\.)\\s+"),
         name_clean = str_squish(name_clean),
         name_clean = str_to_title(name_clean))
customers$name_clean          # [1] "John Smith" "Jane Doe" "Alice Wong" ...

# d) Phone: digits only, French normalisation, validation
customers <- customers %>%
  mutate(phone_digits   = str_remove_all(phone, "[^0-9]"),
         phone_digits   = if_else(phone_digits == "", NA_character_, phone_digits),
         phone_national = case_when(
           str_to_upper(str_trim(country)) %in% c("FR", "FRANCE") &
             str_detect(phone_digits, "^0033") ~
             str_replace(phone_digits, "^0033", "0"),
           str_to_upper(str_trim(country)) %in% c("FR", "FRANCE") &
             str_detect(phone_digits, "^33") & nchar(phone_digits) == 11 ~
             str_replace(phone_digits, "^33", "0"),
           TRUE ~ phone_digits
         ),
         phone_valid = if_else(
           is.na(phone_national),
           NA,
           nchar(phone_national) >= 9 & nchar(phone_national) <= 15
         ))
customers$phone_national[c(1, 8, 18)]   # [1] "0612345678" "0711223344" "0698765432"
sum(customers$phone_valid, na.rm = TRUE)             # [1] 16 valid
sum(!customers$phone_valid, na.rm = TRUE)            # [1] 1 invalid ("911")
sum(is.na(customers$phone_valid))                    # [1] 7 missing

# e) Email: validate with a plausible pattern
customers <- customers %>%
  mutate(email_status = case_when(
    is.na(email) ~ "missing",
    str_detect(email, "^[^@]+@[^@]+\\.[^@]+$") ~ "valid",
    TRUE ~ "invalid"
  ))
table(customers$email_status)   # invalid 2, missing 1, valid 21
# invalid: "jane.doe@" and "olivier.blanc@"

# f) Country: normalise to ISO2 codes
customers <- customers %>%
  mutate(country_code = case_when(
    toupper(str_trim(country)) %in% c("FR", "FRANCE")     ~ "FR",
    toupper(str_trim(country)) %in% c("DE", "GERMANY")    ~ "DE",
    toupper(str_trim(country)) %in% c("US", "USA")        ~ "US",
    toupper(str_trim(country)) %in% c("GB", "UK")         ~ "GB",
    toupper(str_trim(country)) %in% c("IT", "ITALY")      ~ "IT",
    toupper(str_trim(country)) %in% c("ES", "SPAIN")      ~ "ES",
    TRUE                                        ~ toupper(str_trim(country))
  ))
table(customers$country_code)
# CN 1, DE 4, ES 2, FR 10, GB 2, IE 1, IT 2, US 2

# -----------------------------------------------------------------------------
# Exercise 3.3 - Dates & numerics
# -----------------------------------------------------------------------------

# g) Multi-format date parser.
#    IMPORTANT: as.Date(x, format) is LENIENT - it can half-match a string and
#    roll the leftovers into the date (e.g. "04-12-2023" read with %Y-%m-%d
#    becomes year 0004). So we FIRST validate the whole string with anchored
#    regexes, then parse ONLY the values that match that exact format.
parse_date_multi <- function(x) {
  out <- rep(NA_character_, length(x))
  iso <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)   # 2023-04-12
  dmy <- grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", x)   # 12/04/2023
  mdy <- grepl("^[0-9]{2}-[0-9]{2}-[0-9]{4}$", x)   # 04-12-2023
  out[iso] <- format(as.Date(x[iso], format = "%Y-%m-%d"))
  out[dmy] <- format(as.Date(x[dmy], format = "%d/%m/%Y"))
  out[mdy] <- format(as.Date(x[mdy], format = "%m-%d-%Y"))
  as.Date(out)
}
customers <- customers %>%
  mutate(join_date          = parse_date_multi(join_date),
         last_purchase_date = parse_date_multi(last_purchase_date))
sum(is.na(customers$join_date))           # [1] 0 - every date parsed
customers$join_date[c(1, 2, 3)]           # [1] "2023-04-12" "2023-04-12" "2023-04-12"
# Convention used: slashes = DD/MM/YYYY, dashed two-digit-month = MM-DD-YYYY,
# so "04-12-2023" means April 12, 2023.

# h) Orders to integer
customers$orders_num <- as.integer(customers$orders)
sum(is.na(customers$orders_num))          # [1] 1 (CUST-010)

# i) Spend to numeric without losing data
tmp <- str_remove_all(customers$total_spend, "[$,USD ]")   # symbols & separators
tmp <- ifelse(grepl("^\\(.*\\)$", tmp),                    # parentheses = negative
              paste0("-", str_remove_all(tmp, "[\\(\\)]")),
              tmp)
tmp[tolower(tmp) == "n/a"] <- NA_character_
customers$spend_num <- as.numeric(tmp)
customers$spend_num[c(10, 14, 20)]        # [1]  -250.0 2750.0     NA
sum(is.na(customers$spend_num))           # [1] 1 - only the deliberate "n/a"

# -----------------------------------------------------------------------------
# Exercise 3.4 - Features, segmentation & export
# -----------------------------------------------------------------------------

# j) Recency in days since the analysis date
customers$recency_days <- as.numeric(analysis_date - customers$last_purchase_date)
customers$recency_days[c(1, 11)]          # [1] 31 133 - smaller = more recent

# k) Segmentation rule (business-defined)
customers <- customers %>%
  mutate(segment = case_when(
    spend_num >= 3000          ~ "Gold",
    spend_num >= 800           ~ "Silver",
    !is.na(spend_num)          ~ "Bronze",
    TRUE                       ~ NA_character_
  ))

# l) Frequency table of segments
seg_table <- table(customers$segment, useNA = "ifany")
seg_table
# Bronze Gold Silver <NA>
#      7    6     10    1
# Silver is the largest segment.

# m) Summary per segment
customers %>%
  filter(!is.na(segment)) %>%
  group_by(segment) %>%
  summarise(customers   = n(),
            mean_spend  = round(mean(spend_num), 2),
            mean_orders = round(mean(orders_num, na.rm = TRUE), 2),
            mean_recency = round(mean(recency_days), 1)) %>%
  arrange(desc(mean_spend))
#   segment customers mean_spend mean_orders mean_recency
#   Gold            6    4186.57        14.5        120.2
#   Silver         10    1560.57         6.8         95.4
#   Bronze          7     306.86         2.67         99.0

# n) Data quality counts
data.frame(
  issue = c("missing phone", "invalid email", "missing spend",
            "negative spend", "zero spend"),
  count = c(sum(is.na(customers$phone_digits)),
            sum(customers$email_status == "invalid"),
            sum(is.na(customers$spend_num)),
            sum(customers$spend_num < 0, na.rm = TRUE),
            sum(customers$spend_num == 0, na.rm = TRUE))
)
#            issue count
# 1   missing phone     7
# 2   invalid email     2
# 3   missing spend     1
# 4  negative spend     1
# 5     zero spend      1

# o) Export the tidy dataset
write_csv(customers, "data/customers_clean.csv")
# Check the round trip
clean <- read_csv("data/customers_clean.csv", show_col_types = FALSE,
                  col_types = cols(
                    .default = col_character(),
                    join_date = col_date(),
                    last_purchase_date = col_date(),
                    phone_valid = col_logical(),
                    orders_num = col_integer(),
                    spend_num = col_double(),
                    recency_days = col_double()
                  ))
nrow(clean)                    # [1] 24
colSums(is.na(clean))          # only the intended NAs remain
# CSV has no type metadata: explicit character columns preserve phone zeros.
stopifnot(isTRUE(all.equal(as.data.frame(customers), as.data.frame(clean),
                           check.attributes = FALSE)))
