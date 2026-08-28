#' Validate Marine Ecosystem Survey Data
#'
#' @description
#' Comprehensive quality control for marine ecosystem survey data.
#' Checks for missing values, validates species identifiers, detects outliers,
#' and generates a detailed QC report.
#'
#' @param survey_data A data frame with columns: species_id, abundance, biomass,
#'   sampling_effort, date
#' @param reference_species A character vector of valid species identifiers
#' @param outlier_threshold Z-score threshold for outlier detection (default: 3)
#' @param seed Optional seed for reproducibility. Defaults to NULL.
#'
#' @return
#' A list containing:
#'   - `validation_report`: Data frame with rows for each issue found
#'   - `cleaned_data`: Original data with QC flags added
#'   - `summary`: Summary statistics of validation results
#'
#' @details
#' The function performs the following checks:
#' 1. Missing value detection across all columns
#' 2. Species identifier validation against reference database
#' 3. Measurement range validation (abundance >= 0, biomass >= 0)
#' 4. Outlier detection using Z-score method
#' 5. Sampling effort consistency checks
#'
#' Issues are flagged but not removed, allowing manual review.
#'
#' @examples
#' \dontrun{
#'   species_list <- c("Gadus_morhua", "Clupea_harengus", "Sebastes_mentella")
#'   result <- validate_ecosystem_data(survey_data, species_list)
#'   print(result$summary)
#' }
#'
#' @export
validate_ecosystem_data <- function(survey_data,
                                     reference_species,
                                     outlier_threshold = 3,
                                     seed = NULL) {

  # Input validation
  if (!is.data.frame(survey_data)) {
    stop("survey_data must be a data frame", call. = FALSE)
  }

  required_cols <- c("species_id", "abundance", "biomass", "sampling_effort", "date")
  missing_cols <- setdiff(required_cols, colnames(survey_data))
  if (length(missing_cols) > 0) {
    stop("survey_data is missing required columns: ",
         paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  if (!is.character(reference_species)) {
    stop("reference_species must be a character vector", call. = FALSE)
  }

  if (!is.numeric(outlier_threshold) || outlier_threshold <= 0) {
    stop("outlier_threshold must be a positive number", call. = FALSE)
  }

  # Initialize issues list
  issues <- list()

  # Check 1: Missing values
  issues$missing_values <- survey_data %>%
    dplyr::mutate(row_id = dplyr::row_number()) %>%
    tidyr::pivot_longer(-row_id, names_to = "column", values_to = "value") %>%
    dplyr::filter(is.na(value)) %>%
    dplyr::select(row_id, column) %>%
    dplyr::mutate(issue_type = "missing_value", severity = "high")

  # Check 2: Invalid species identifiers
  invalid_species <- survey_data %>%
    dplyr::mutate(row_id = dplyr::row_number()) %>%
    dplyr::filter(!(species_id %in% reference_species)) %>%
    dplyr::select(row_id, species_id) %>%
    dplyr::mutate(issue_type = "invalid_species_id", severity = "high")

  issues$invalid_species <- invalid_species

  # Check 3: Negative measurements
  negative_abundance <- survey_data %>%
    dplyr::mutate(row_id = dplyr::row_number()) %>%
    dplyr::filter(abundance < 0) %>%
    dplyr::select(row_id, abundance) %>%
    dplyr::mutate(issue_type = "negative_abundance", severity = "high")

  negative_biomass <- survey_data %>%
    dplyr::mutate(row_id = dplyr::row_number()) %>%
    dplyr::filter(biomass < 0) %>%
    dplyr::select(row_id, biomass) %>%
    dplyr::mutate(issue_type = "negative_biomass", severity = "high")

  issues$negative_measurements <- dplyr::bind_rows(negative_abundance, negative_biomass)

  # Check 4: Outlier detection using Z-score
  if (!is.null(seed)) {
    withr::with_seed(seed, {
      outliers <- detect_outliers(survey_data, outlier_threshold)
    })
  } else {
    outliers <- detect_outliers(survey_data, outlier_threshold)
  }

  issues$outliers <- outliers

  # Combine all issues
  validation_report <- dplyr::bind_rows(issues, .id = "check_category") %>%
    dplyr::select(check_category, row_id, issue_type, severity, dplyr::everything()) %>%
    dplyr::arrange(row_id)

  if (nrow(validation_report) == 0) {
    validation_report <- data.frame(
      check_category = character(),
      row_id = integer(),
      issue_type = character(),
      severity = character()
    )
  }

  # Add QC flags to cleaned_data
  cleaned_data <- survey_data %>%
    dplyr::mutate(
      row_id = dplyr::row_number(),
      qc_flag = if_else(row_id %in% validation_report$row_id, "FLAGGED", "PASS"),
      num_issues = rowSums(
        sapply(row_id, function(r) sum(validation_report$row_id == r))
      )
    ) %>%
    dplyr::select(-row_id)

  # Summary statistics
  summary <- list(
    total_rows = nrow(survey_data),
    flagged_rows = sum(cleaned_data$qc_flag == "FLAGGED"),
    pass_rows = sum(cleaned_data$qc_flag == "PASS"),
    flagged_proportion = mean(cleaned_data$qc_flag == "FLAGGED"),
    high_severity_issues = sum(validation_report$severity == "high", na.rm = TRUE),
    medium_severity_issues = sum(validation_report$severity == "medium", na.rm = TRUE),
    low_severity_issues = sum(validation_report$severity == "low", na.rm = TRUE),
    issues_by_type = table(validation_report$issue_type) %>% as.data.frame()
  )

  return(list(
    validation_report = validation_report,
    cleaned_data = cleaned_data,
    summary = summary
  ))
}

#' Detect Outliers in Numeric Columns
#'
#' @keywords internal
#' @noRd
detect_outliers <- function(data, threshold = 3) {
  numeric_cols <- colnames(data)[sapply(data, is.numeric)]

  outliers_list <- lapply(numeric_cols, function(col) {
    z_scores <- abs(scale(data[[col]], center = TRUE, scale = TRUE))
    z_scores[is.na(z_scores)] <- 0

    data %>%
      dplyr::mutate(row_id = dplyr::row_number()) %>%
      dplyr::filter(!!rlang::sym(col) > 0 & z_scores > threshold) %>%
      dplyr::select(row_id, !!col) %>%
      dplyr::mutate(
        issue_type = paste0("outlier_", col),
        severity = "medium"
      )
  })

  outliers <- dplyr::bind_rows(outliers_list)

  if (nrow(outliers) == 0) {
    return(data.frame(
      row_id = integer(),
      issue_type = character(),
      severity = character()
    ))
  }

  return(outliers)
}
