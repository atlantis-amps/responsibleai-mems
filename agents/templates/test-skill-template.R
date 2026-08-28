# Test suite template for agent skills
# Place this in skills/{category}/{skill-name}/tests/test-{skill-name}.R

library(testthat)

# Load the skill function
source("../implementation.R")

test_that("skill_function validates input types", {
  expect_error(
    skill_function("not a data frame"),
    "input_data must be a data frame"
  )
})

test_that("skill_function returns a data frame", {
  test_data <- data.frame(
    id = 1:5,
    value = rnorm(5)
  )

  result <- skill_function(test_data)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 5)
})

test_that("skill_function handles seed parameter", {
  test_data <- data.frame(value = 1:10)

  result1 <- skill_function(test_data, seed = 42)
  result2 <- skill_function(test_data, seed = 42)

  expect_equal(result1, result2)
})

test_that("skill_function preserves data structure", {
  test_data <- data.frame(
    id = 1:3,
    name = c("a", "b", "c"),
    value = c(1.5, 2.5, 3.5)
  )

  result <- skill_function(test_data)

  expect_equal(nrow(result), nrow(test_data))
  expect_equal(colnames(result), colnames(test_data))
})

test_that("skill_function handles missing values appropriately", {
  test_data <- data.frame(
    id = 1:5,
    value = c(1, NA, 3, NaN, 5)
  )

  result <- skill_function(test_data)

  # Document how your function handles NA/NaN
  expect_equal(result$id, test_data$id)
})

# Snapshot testing for complex outputs
test_that("skill_function output matches snapshot", {
  test_data <- data.frame(
    id = 1:3,
    value = c(1.23456, 2.34567, 3.45678)
  )

  result <- skill_function(test_data)

  expect_snapshot(result)
})
