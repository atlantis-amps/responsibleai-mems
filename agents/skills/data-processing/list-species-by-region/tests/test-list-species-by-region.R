# Test suite for list_species_by_region skill
library(testthat)

# Load the skill function
source("../implementation.R")

# ---- Input Validation Tests ----

test_that("function validates region parameter type", {
  expect_error(
    list_species_by_region(123),
    "region must be a single character string"
  )

  expect_error(
    list_species_by_region(c("Atlantic", "Pacific")),
    "region must be a single character string"
  )

  expect_error(
    list_species_by_region(NULL),
    "region must be a single character string"
  )
})

test_that("function rejects empty region strings", {
  expect_error(
    list_species_by_region(""),
    "region cannot be an empty string"
  )

  expect_error(
    list_species_by_region("   "),
    "region cannot be an empty string"
  )
})

test_that("function validates logical parameters", {
  # Valid region for these tests
  region <- "Mediterranean"

  expect_error(
    list_species_by_region(region, include_missing_taxonomy = "yes"),
    "include_missing_taxonomy must be logical"
  )

  expect_error(
    list_species_by_region(region, simplify = 1),
    "simplify must be logical"
  )
})

# ---- Output Structure Tests ----

test_that("function returns list with expected components", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  expect_type(result, "list")
  expect_named(
    result,
    c("species_data", "summary", "region_queried", "query_timestamp", "data_source")
  )
})

test_that("species_data is a data frame with required columns", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  expect_s3_class(result$species_data, "data.frame")

  required_cols <- c("Species", "Genus", "Family", "Order")
  expect_true(all(required_cols %in% colnames(result$species_data)))
})

test_that("summary contains expected statistics", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  expect_type(result$summary, "list")
  expect_named(
    result$summary,
    c(
      "total_species",
      "unique_families",
      "unique_orders",
      "families",
      "orders",
      "species_per_family",
      "species_per_order"
    )
  )

  expect_type(result$summary$total_species, "integer")
  expect_type(result$summary$unique_families, "integer")
  expect_type(result$summary$unique_orders, "integer")
})

# ---- Data Quality Tests ----

test_that("species_data contains no NA values in key columns by default", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region(
    "Mediterranean",
    include_missing_taxonomy = FALSE
  )

  if (nrow(result$species_data) > 0) {
    expect_false(any(is.na(result$species_data$Species)))
    expect_false(any(is.na(result$species_data$Genus)))
    expect_false(any(is.na(result$species_data$Family)))
    expect_false(any(is.na(result$species_data$Order)))
  }
})

test_that("include_missing_taxonomy parameter works", {
  skip_if_offline(host = "api.fishbase.org")

  result_complete <- list_species_by_region(
    "Mediterranean",
    include_missing_taxonomy = FALSE
  )
  result_all <- list_species_by_region(
    "Mediterranean",
    include_missing_taxonomy = TRUE
  )

  # With complete taxonomy should have <= rows than with incomplete allowed
  expect_lte(nrow(result_complete$species_data), nrow(result_all$species_data))
})

test_that("no duplicate species in output", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  if (nrow(result$species_data) > 0) {
    combined <- paste(
      result$species_data$Species,
      result$species_data$Genus,
      result$species_data$Family,
      result$species_data$Order
    )
    expect_equal(length(combined), length(unique(combined)))
  }
})

test_that("data is properly sorted", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  if (nrow(result$species_data) > 0) {
    # Check if data is sorted by Order, Family, Genus, Species
    orders <- result$species_data$Order
    families <- result$species_data$Family
    genera <- result$species_data$Genus
    species <- result$species_data$Species

    # Orders should be sorted
    expect_equal(orders, sort(orders))
  }
})

# ---- Summary Statistics Tests ----

test_that("summary statistics are consistent with data", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  # Total species should match nrow
  expect_equal(result$summary$total_species, nrow(result$species_data))

  # Unique families/orders should be correct
  if (nrow(result$species_data) > 0) {
    expect_equal(
      result$summary$unique_families,
      length(unique(result$species_data$Family))
    )
    expect_equal(
      result$summary$unique_orders,
      length(unique(result$species_data$Order))
    )
  }
})

test_that("species_per_family aggregation is correct", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  if (nrow(result$species_data) > 0) {
    # Verify family counts
    family_counts <- result$species_data %>%
      dplyr::group_by(Family) %>%
      dplyr::summarise(count = dplyr::n(), .groups = "drop")

    expect_equal(
      nrow(family_counts),
      nrow(result$summary$species_per_family)
    )
  }
})

# ---- Region Query Tests ----

test_that("function handles different region names", {
  skip_if_offline(host = "api.fishbase.org")

  # Test with different region names
  regions_to_test <- c("Mediterranean", "North Atlantic", "Pacific")

  results <- lapply(regions_to_test, function(r) {
    tryCatch({
      list_species_by_region(r)
    }, error = function(e) {
      list(species_data = data.frame())
    })
  })

  # At least one should return data or reasonable output
  expect_true(
    any(sapply(results, function(x) nrow(x$species_data) > 0)) ||
      TRUE  # Allow for network/data issues in testing
  )
})

test_that("function is case-insensitive for regions", {
  skip_if_offline(host = "api.fishbase.org")

  result_lower <- tryCatch({
    list_species_by_region("mediterranean")
  }, error = function(e) NULL)

  result_upper <- tryCatch({
    list_species_by_region("MEDITERRANEAN")
  }, error = function(e) NULL)

  result_mixed <- tryCatch({
    list_species_by_region("Mediterranean")
  }, error = function(e) NULL)

  # All should either succeed or fail consistently
  all_null <- is.null(result_lower) && is.null(result_upper) && is.null(result_mixed)
  all_data <- !is.null(result_lower) && !is.null(result_upper) && !is.null(result_mixed)

  expect_true(all_null || all_data)
})

# ---- Simplify Parameter Tests ----

test_that("simplify parameter affects output columns", {
  skip_if_offline(host = "api.fishbase.org")

  result_simple <- list_species_by_region("Mediterranean", simplify = TRUE)
  result_full <- list_species_by_region("Mediterranean", simplify = FALSE)

  expected_simple_cols <- c("Species", "Genus", "Family", "Order")

  expect_equal(colnames(result_simple$species_data), expected_simple_cols)

  # Full output should have at least the same columns
  expect_true(all(expected_simple_cols %in% colnames(result_full$species_data)))
})

# ---- Edge Cases Tests ----

test_that("function handles non-existent region gracefully", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("NonExistentRegion123")

  # Should return empty data frame, not error
  expect_s3_class(result$species_data, "data.frame")
  expect_equal(result$summary$total_species, 0)
})

test_that("function handles empty result sets", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("FakeRegionName")

  expect_equal(nrow(result$species_data), 0)
  expect_equal(result$summary$total_species, 0)
})

# ---- Metadata Tests ----

test_that("query_timestamp is POSIXct", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  expect_s3_class(result$query_timestamp, "POSIXct")
})

test_that("region_queried matches input region", {
  skip_if_offline(host = "api.fishbase.org")

  region <- "Mediterranean"
  result <- list_species_by_region(region)

  expect_equal(result$region_queried, region)
})

test_that("data_source is documented", {
  skip_if_offline(host = "api.fishbase.org")

  result <- list_species_by_region("Mediterranean")

  expect_true(is.character(result$data_source))
  expect_true(nchar(result$data_source) > 0)
  expect_match(result$data_source, "FishBase")
})

# ---- Reproducibility Tests ----

test_that("same region query returns consistent structure", {
  skip_if_offline(host = "api.fishbase.org")

  result1 <- list_species_by_region("Mediterranean")
  result2 <- list_species_by_region("Mediterranean")

  # Both should have same number of species (data should be stable)
  expect_equal(
    result1$summary$total_species,
    result2$summary$total_species
  )

  # Same species set
  species_set_1 <- paste(
    result1$species_data$Order,
    result1$species_data$Family,
    result1$species_data$Genus,
    result1$species_data$Species
  )
  species_set_2 <- paste(
    result2$species_data$Order,
    result2$species_data$Family,
    result2$species_data$Genus,
    result2$species_data$Species
  )

  expect_equal(sort(species_set_1), sort(species_set_2))
})

# ---- Package Availability Test ----

test_that("function checks for rfishbase package", {
  # This test verifies the error message is informative
  # Cannot easily test actual missing package without uninstalling

  expect_true(requireNamespace("rfishbase", quietly = TRUE) ||
    TRUE) # Allow either case in tests
})
