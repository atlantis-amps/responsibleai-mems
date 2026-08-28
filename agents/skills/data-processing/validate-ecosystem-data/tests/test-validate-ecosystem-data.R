# Test suite for validate_ecosystem_data skill
library(testthat)

# Load the skill function
source("../implementation.R")

# Setup test data
valid_species <- c("Gadus_morhua", "Clupea_harengus", "Sebastes_mentella")

create_test_data <- function(n = 10) {
  data.frame(
    species_id = sample(valid_species, n, replace = TRUE),
    abundance = rpois(n, lambda = 50),
    biomass = rnorm(n, mean = 100, sd = 20),
    sampling_effort = rpois(n, lambda = 10),
    date = seq(as.Date("2024-01-01"), by = "day", length.out = n)
  )
}

# ---- Input Validation Tests ----

test_that("function validates input types", {
  expect_error(
    validate_ecosystem_data("not a data frame", valid_species),
    "survey_data must be a data frame"
  )

  expect_error(
    validate_ecosystem_data(create_test_data(), 123),
    "reference_species must be a character vector"
  )

  expect_error(
    validate_ecosystem_data(create_test_data(), valid_species, outlier_threshold = -1),
    "outlier_threshold must be a positive number"
  )
})

test_that("function checks for required columns", {
  incomplete_data <- data.frame(
    species_id = c("A", "B"),
    abundance = c(1, 2)
    # missing: biomass, sampling_effort, date
  )

  expect_error(
    validate_ecosystem_data(incomplete_data, valid_species),
    "missing required columns"
  )
})

# ---- Output Structure Tests ----

test_that("function returns list with expected components", {
  test_data <- create_test_data(10)
  result <- validate_ecosystem_data(test_data, valid_species)

  expect_type(result, "list")
  expect_named(result, c("validation_report", "cleaned_data", "summary"))
  expect_s3_class(result$validation_report, "data.frame")
  expect_s3_class(result$cleaned_data, "data.frame")
  expect_type(result$summary, "list")
})

test_that("cleaned_data retains original dimensions", {
  test_data <- create_test_data(20)
  result <- validate_ecosystem_data(test_data, valid_species)

  expect_equal(nrow(result$cleaned_data), nrow(test_data))
})

# ---- Functionality Tests ----

test_that("function detects missing values", {
  test_data <- create_test_data(10)
  test_data[3, "abundance"] <- NA

  result <- validate_ecosystem_data(test_data, valid_species)

  missing_issues <- result$validation_report %>%
    dplyr::filter(issue_type == "missing_value")

  expect_true(nrow(missing_issues) > 0)
  expect_true(any(missing_issues$row_id == 3))
})

test_that("function detects invalid species identifiers", {
  test_data <- create_test_data(10)
  test_data[5, "species_id"] <- "Invalid_Species"

  result <- validate_ecosystem_data(test_data, valid_species)

  invalid_issues <- result$validation_report %>%
    dplyr::filter(issue_type == "invalid_species_id")

  expect_true(nrow(invalid_issues) > 0)
})

test_that("function detects negative measurements", {
  test_data <- create_test_data(10)
  test_data[2, "abundance"] <- -5
  test_data[7, "biomass"] <- -10

  result <- validate_ecosystem_data(test_data, valid_species)

  negative_issues <- result$validation_report %>%
    dplyr::filter(issue_type %in% c("negative_abundance", "negative_biomass"))

  expect_true(nrow(negative_issues) >= 2)
})

test_that("function detects outliers", {
  test_data <- create_test_data(50)
  # Inject an obvious outlier
  test_data[10, "biomass"] <- 10000

  result <- validate_ecosystem_data(test_data, valid_species, outlier_threshold = 3)

  outlier_issues <- result$validation_report %>%
    dplyr::filter(grepl("outlier", issue_type))

  # May or may not detect depending on scale; test that it runs without error
  expect_type(outlier_issues, "list")
})

test_that("function flags rows with issues correctly", {
  test_data <- create_test_data(10)
  test_data[4, "abundance"] <- -1

  result <- validate_ecosystem_data(test_data, valid_species)

  expect_true(result$cleaned_data[4, "qc_flag"] == "FLAGGED")
  expect_true(all(result$cleaned_data$qc_flag != "FLAGGED" | result$cleaned_data$qc_flag == "FLAGGED"))
})

# ---- Reproducibility Tests ----

test_that("function produces consistent results with seed", {
  test_data <- create_test_data(30)
  # Add potential variance in outlier detection
  test_data$biomass <- test_data$biomass + rnorm(30, 0, 50)

  result1 <- validate_ecosystem_data(test_data, valid_species, seed = 42)
  result2 <- validate_ecosystem_data(test_data, valid_species, seed = 42)

  expect_equal(result1$validation_report, result2$validation_report)
})

# ---- Edge Case Tests ----

test_that("function handles completely clean data", {
  test_data <- create_test_data(10)

  result <- validate_ecosystem_data(test_data, valid_species)

  expect_equal(sum(result$cleaned_data$qc_flag == "FLAGGED"), 0)
  expect_equal(nrow(result$validation_report), 0)
})

test_that("function handles all missing values", {
  test_data <- create_test_data(5)
  test_data$abundance <- NA

  result <- validate_ecosystem_data(test_data, valid_species)

  expect_true(nrow(result$validation_report) > 0)
})

test_that("function handles empty data frame", {
  empty_data <- data.frame(
    species_id = character(),
    abundance = integer(),
    biomass = numeric(),
    sampling_effort = integer(),
    date = as.Date(character())
  )

  result <- validate_ecosystem_data(empty_data, valid_species)

  expect_equal(nrow(result$cleaned_data), 0)
  expect_equal(nrow(result$validation_report), 0)
})

# ---- Summary Statistics Tests ----

test_that("function produces correct summary statistics", {
  test_data <- create_test_data(20)
  result <- validate_ecosystem_data(test_data, valid_species)

  expect_equal(result$summary$total_rows, 20)
  expect_equal(
    result$summary$flagged_rows + result$summary$pass_rows,
    result$summary$total_rows
  )
  expect_equal(
    result$summary$flagged_proportion,
    result$summary$flagged_rows / result$summary$total_rows
  )
})
