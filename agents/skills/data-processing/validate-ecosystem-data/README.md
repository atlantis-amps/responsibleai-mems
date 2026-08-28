# Skill: Validate Ecosystem Survey Data

## Purpose

This skill provides comprehensive quality control (QC) for marine ecosystem survey data. It validates data integrity, detects anomalies, and generates detailed reports of potential issues for manual review.

**When to use:**
- After importing raw survey data from field collections
- Before conducting statistical analysis or modeling
- To verify data structure and content consistency
- To identify data quality issues for remediation

## Usage

```r
source("agents/skills/data-processing/validate-ecosystem-data/implementation.R")

# Define reference species list
species_reference <- c(
  "Gadus_morhua",
  "Clupea_harengus",
  "Sebastes_mentella",
  "Melanogrammus_aeglefinus"
)

# Run validation
result <- validate_ecosystem_data(
  survey_data = my_survey_df,
  reference_species = species_reference,
  outlier_threshold = 3
)

# Review results
print(result$summary)
print(result$validation_report)
```

## Parameters

### `survey_data` (data.frame, required)

Survey data containing the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `species_id` | character | Scientific name or code (must match reference list) |
| `abundance` | numeric | Count or density (must be ≥ 0) |
| `biomass` | numeric | Mass in grams or kg (must be ≥ 0) |
| `sampling_effort` | numeric | Effort metric (e.g., trap hours, net duration) |
| `date` | Date | Sampling date |

### `reference_species` (character vector, required)

Vector of valid species identifiers. Example:

```r
reference_species <- c("Gadus_morhua", "Clupea_harengus", "Sebastes_mentella")
```

### `outlier_threshold` (numeric, optional)

Z-score threshold for outlier detection. Default: **3**

- Lower values (1.96 ≈ 95%) are more sensitive
- Higher values (3 ≈ 99.7%) are more conservative
- Set to `Inf` to disable outlier checking

### `seed` (integer, optional)

Random seed for reproducibility. If not specified, results may vary slightly due to numerical precision in outlier detection.

## Returns

A **list** with three components:

### 1. `validation_report` (data.frame)

Detailed record of all issues found:

| Column | Description |
|--------|-------------|
| `check_category` | Category of check (missing_values, invalid_species, etc.) |
| `row_id` | Row number where issue was detected |
| `issue_type` | Specific type of issue |
| `severity` | Issue severity: `high`, `medium`, or `low` |

### 2. `cleaned_data` (data.frame)

Original data with two additional columns:

| Column | Description |
|--------|-------------|
| `qc_flag` | `"PASS"` or `"FLAGGED"` indicating if row has issues |
| `num_issues` | Count of issues detected in that row |

### 3. `summary` (list)

Summary statistics:

```
$total_rows: Total number of survey records
$flagged_rows: Count of rows with issues
$pass_rows: Count of rows without issues
$flagged_proportion: Proportion of flagged rows (0-1)
$high_severity_issues: Count of high-severity issues
$medium_severity_issues: Count of medium-severity issues
$low_severity_issues: Count of low-severity issues
$issues_by_type: Table of issue counts by type
```

## Quality Checks Performed

### 1. Missing Value Detection
Identifies `NA` values in required columns.
- **Severity:** High
- **Action:** Review and decide whether to remove or impute

### 2. Species Validation
Checks if `species_id` matches reference database.
- **Severity:** High
- **Action:** Verify species name spelling or update reference list

### 3. Measurement Range Validation
Ensures `abundance` and `biomass` are non-negative.
- **Severity:** High
- **Action:** Investigate data entry errors

### 4. Outlier Detection
Uses Z-score method to identify unusual measurements.
- **Severity:** Medium
- **Action:** Verify field notes; may be legitimate biological variation

### 5. Sampling Effort Consistency
Flags rows with zero or missing sampling effort (optional).
- **Severity:** Medium
- **Action:** Verify effort was actually applied

## Examples

### Basic Usage

```r
# Load example data
data(example_survey)

# Reference species for this study
species <- c("Gadus_morhua", "Clupea_harengus")

# Validate
qc_result <- validate_ecosystem_data(example_survey, species)

# Show how many rows pass QC
cat("Pass rate:", qc_result$summary$pass_rows / qc_result$summary$total_rows)

# Show flagged rows
flagged <- qc_result$cleaned_data %>%
  filter(qc_flag == "FLAGGED") %>%
  select(species_id, abundance, biomass, num_issues)
```

### Investigating Issues

```r
# Get all high-severity issues
high_severity <- qc_result$validation_report %>%
  filter(severity == "high") %>%
  group_by(issue_type) %>%
  summarise(count = n())

print(high_severity)

# Examine specific issue type
missing_val_rows <- qc_result$validation_report %>%
  filter(issue_type == "missing_value") %>%
  pull(row_id)

print(my_survey[missing_val_rows, ])
```

### Creating a Clean Dataset

```r
# Option 1: Keep flagged rows but add notes
clean_survey <- qc_result$cleaned_data %>%
  mutate(
    qc_reviewed = if_else(qc_flag == "FLAGGED", "NEEDS_REVIEW", "APPROVED")
  )

# Option 2: Filter out flagged rows
clean_survey <- qc_result$cleaned_data %>%
  filter(qc_flag == "PASS") %>%
  select(-qc_flag, -num_issues)
```

## Assumptions & Limitations

### Assumptions

1. **Abundance ≥ 0**: Negative abundances indicate data entry errors
2. **Biomass ≥ 0**: Negative biomass is impossible
3. **Normal Distribution**: Outlier detection assumes approximately normal distribution of measurements
4. **Reference Species Complete**: All true species are in the reference list
5. **Date Format**: Dates must be in standard Date format

### Limitations

1. **No Geographic Validation**: Does not check if coordinates are plausible
2. **No Temporal Checks**: Does not verify temporal consistency (e.g., species migration patterns)
3. **No Covariates**: Does not account for environmental factors that might explain outliers
4. **Binary Classification**: Flags as "PASS" or "FLAGGED"; cannot distinguish minor vs. major issues
5. **No Automatic Correction**: All issues flagged for manual review; no automatic imputation

## Scientific Rigor Notes

- This skill follows functional programming principles (no global assignment)
- Missing value handling is explicit and documented
- Outlier detection parameters are transparent and adjustable
- All results are reproducible with explicit seed parameter
- Floating-point calculations use appropriate tolerance (`1e-6`)

## References

- [Zuur et al. (2010) - Protocols for Data Exploration to Avoid Common Statistical Problems](https://doi.org/10.1111/j.1365-2656.2009.01629.x)
- [ISO/IEC Guide 35:2017 - Certification of reference materials](https://www.iso.org/standard/64416.html)
- R documentation: `base::scale()`, `stats::na.omit()`

## Troubleshooting

### "Species not in reference list"
Verify spelling and format match exactly. Species names are case-sensitive.

### "Too many outliers detected"
Try increasing `outlier_threshold` (e.g., from 3 to 4) or investigate whether data truly has high variability.

### "No issues found but data looks wrong"
This skill catches common data quality issues but not domain-specific problems. Consider additional domain expert review.

## Testing

Run the test suite:

```r
Rscript -e "testthat::test_dir('agents/skills/data-processing/validate-ecosystem-data/tests')"
```

---

**Last Updated:** 2026-08-28  
**Status:** ✅ Stable (v0.1.0)
