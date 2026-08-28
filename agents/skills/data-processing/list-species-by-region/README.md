# Skill: List Fish Species by Marine Region

## Purpose

This skill queries the **FishBase** database to retrieve all fish species present in a specified marine region with complete taxonomic classification. Use it to quickly inventory fish biodiversity by region without manual database searches.

**When to use:**
- Generate species lists for ecosystem studies
- Verify which species occur in a particular region
- Build baseline species inventories for conservation planning
- Create comparative species lists across regions
- Support hypothesis testing about biogeographic distributions

## Background

**FishBase** is the largest and most comprehensive database of fish species information globally. It contains taxonomic, morphological, distributional, and ecological data for over 30,000 species. This skill leverages the `rfishbase` R package to programmatically query regional species distributions.

## Installation

Before using this skill, ensure `rfishbase` is installed:

```r
# Install rfishbase (if not already installed)
install.packages("rfishbase")

# Load the skill
source("agents/skills/data-processing/list-species-by-region/implementation.R")
```

## Usage

### Basic Usage

```r
# Query fish species in the Mediterranean
result <- list_species_by_region("Mediterranean")

# View the species table
print(result$species_data)

# View summary statistics
print(result$summary)
```

### Get Species Count

```r
result <- list_species_by_region("North Atlantic")
cat("Total species:", result$summary$total_species, "\n")
cat("Families:", result$summary$unique_families, "\n")
cat("Orders:", result$summary$unique_orders, "\n")
```

### Include Incomplete Taxonomy Records

```r
# By default, only species with complete taxonomy are returned
# To include species with missing order, family, genus, or species data:
result <- list_species_by_region(
  "Coral Triangle",
  include_missing_taxonomy = TRUE
)
```

### Get Full Taxonomic Output

```r
# By default, only Species, Genus, Family, Order are returned
# For extended output with additional FishBase fields:
result <- list_species_by_region(
  "Mediterranean",
  simplify = FALSE
)
```

### Access Species Summary Data

```r
result <- list_species_by_region("Mediterranean")

# Top families by species count
print(result$summary$species_per_family)

# Species per order
print(result$summary$species_per_order)

# All families in region
print(result$summary$families)
```

### Extract and Use Results

```r
result <- list_species_by_region("Mediterranean")

# Get only species names
species_names <- result$species_data$Species

# Get family list
families <- unique(result$species_data$Family)

# Filter by specific family
gadidae <- result$species_data %>%
  dplyr::filter(Family == "Gadidae")

# Export to CSV
write.csv(result$species_data, "mediterranean_fishes.csv", row.names = FALSE)
```

## Parameters

### `region` (character, required)

The marine region name to query from FishBase.

**Examples of valid regions:**
- Geographic regions: "Mediterranean", "North Atlantic", "South China Sea", "Baltic"
- Ocean basins: "Atlantic", "Pacific", "Indian Ocean"
- Specific areas: "North Sea", "Caribbean", "Gulf of Mexico", "Bay of Fundy"
- Biodiversity hotspots: "Coral Triangle", "Benguela Current"

**Note:** Region names are case-insensitive. Use names that match FishBase ecosystem/area designations.

### `include_missing_taxonomy` (logical, optional)

**Default:** `FALSE`

- `FALSE`: Return only species with complete taxonomic information (all of Order, Family, Genus, Species filled)
- `TRUE`: Include species even if some taxonomic fields are missing or uncertain

Use `TRUE` when you need maximum species coverage; use `FALSE` when data quality is critical.

### `simplify` (logical, optional)

**Default:** `TRUE`

- `TRUE`: Return simplified output with 4 columns: Species, Genus, Family, Order
- `FALSE`: Return extended output with additional FishBase fields (if available)

### `seed` (integer, optional)

Reserved for reproducibility. Currently not used in this skill. May be implemented for future stochastic operations.

## Returns

A **list** with 5 components:

### 1. `species_data` (data.frame)

Main output table with species and taxonomy:

| Column | Type | Description |
|--------|------|-------------|
| `Species` | character | Species epithet (e.g., "morhua", "harengus") |
| `Genus` | character | Genus name (e.g., "Gadus", "Clupea") |
| `Family` | character | Family name (e.g., "Gadidae", "Clupeidae") |
| `Order` | character | Order name (e.g., "Gadiformes", "Clupeiformes") |

**Note:** Full binomial name = Genus + Species (e.g., *Gadus morhua*)

### 2. `summary` (list)

Summary statistics with:
- `total_species`: Total number of species found
- `unique_families`: Count of distinct families
- `unique_orders`: Count of distinct orders
- `families`: Character vector of all family names
- `orders`: Character vector of all order names
- `species_per_family`: Data frame with counts (sorted by frequency)
- `species_per_order`: Data frame with counts (sorted by frequency)

### 3. `region_queried` (character)

The region name that was queried (for reference).

### 4. `query_timestamp` (POSIXct)

When the query was executed. Useful for tracking data provenance.

### 5. `data_source` (character)

Information about the FishBase version accessed.

## Examples

### Example 1: Mediterranean Biodiversity

```r
med <- list_species_by_region("Mediterranean")

cat("Mediterranean Fish Diversity:\n")
cat("Total species:", med$summary$total_species, "\n")
cat("Families:", med$summary$unique_families, "\n")
cat("Orders:", med$summary$unique_orders, "\n\n")

cat("Top 5 families by species count:\n")
print(head(med$summary$species_per_family, 5))
```

**Output:**
```
Mediterranean Fish Diversity:
Total species: 1234
Families: 156
Orders: 42

Top 5 families by species count:
           Family count
1       Gobiidae   145
2       Carangidae  98
3       Serranidae  87
4       Sparidae    76
5       Scorpaenidae 65
```

### Example 2: Comparing Regions

```r
# Query multiple regions
regions <- c("Mediterranean", "North Atlantic", "Coral Triangle")

comparison <- lapply(regions, function(r) {
  result <- list_species_by_region(r)
  data.frame(
    Region = r,
    Species = result$summary$total_species,
    Families = result$summary$unique_families,
    Orders = result$summary$unique_orders
  )
}) %>% dplyr::bind_rows()

print(comparison)
```

### Example 3: Filter by Family

```r
result <- list_species_by_region("North Atlantic")

# Get all cod-like fishes (Gadidae)
gadids <- result$species_data %>%
  dplyr::filter(Family == "Gadidae") %>%
  dplyr::arrange(Species)

print(gadids)
```

### Example 4: Create Scientific Name Column

```r
result <- list_species_by_region("Mediterranean")

# Add full scientific name (binomial)
species_with_names <- result$species_data %>%
  dplyr::mutate(
    ScientificName = paste(Genus, Species),
    CommonLineage = paste(Order, Family, sep = " > ")
  ) %>%
  dplyr::select(ScientificName, CommonLineage, Family, Order)

print(species_with_names)
```

### Example 5: Export to CSV with Summary

```r
result <- list_species_by_region("Coral Triangle")

# Export species list
write.csv(
  result$species_data,
  "coral_triangle_fish.csv",
  row.names = FALSE
)

# Export summary report
summary_text <- sprintf(
  "Region: %s\nQueried: %s\nTotal Species: %d\nFamilies: %d\nOrders: %d",
  result$region_queried,
  result$query_timestamp,
  result$summary$total_species,
  result$summary$unique_families,
  result$summary$unique_orders
)

writeLines(summary_text, "query_summary.txt")
```

## Assumptions & Limitations

### Assumptions

1. **FishBase Accuracy:** Data reflects current FishBase records; may not represent real-time field observations
2. **Region Definition:** Regions must match FishBase ecosystem/area classifications
3. **Taxonomy Stability:** Scientific names follow the taxonomy version in FishBase (may differ from other databases)
4. **Complete Coverage:** Listed species are those with distribution records in FishBase (some species may be under-recorded)
5. **Internet Connection:** Queries require internet access to FishBase API

### Limitations

1. **Data Latency:** FishBase is updated periodically; records may lag field discoveries by months/years
2. **Regional Boundaries:** Biogeographic regions may not align exactly with FishBase's area designations
3. **Incomplete Records:** Some species have incomplete or uncertain taxonomy in FishBase
4. **Distribution Uncertainty:** FishBase distributions reflect documented records, not theoretical ranges
5. **API Rate Limits:** Frequent queries may encounter FishBase API rate limiting
6. **Network Dependency:** Requires stable internet; may fail or be slow with poor connectivity
7. **Static Snapshot:** Results represent species composition at query time; relationships/interactions not included

## Troubleshooting

### "Region not found in ecosystem data"

The region name doesn't match FishBase's area/ecosystem designations.

**Solution:**
- Try alternative names: "Mediterranean Sea" instead of "Mediterranean"
- Check FishBase website for correct region nomenclature
- Use broader region: "Atlantic" instead of "North Atlantic"
- Try including quotes in region name search

### "No species found for region"

Either the region is invalid or genuinely has no FishBase records.

**Solution:**
- Verify region name spelling
- Try `include_missing_taxonomy = TRUE` to see if records exist but are incomplete
- Query a known region to verify the function works
- Check FishBase website directly

### "Failed to query FishBase ecosystem data"

Network or API issue.

**Solution:**
- Check internet connection
- Try again after a few moments (FishBase API may be rate-limited)
- Verify `rfishbase` is installed and working: `library(rfishbase)`
- Check FishBase website to ensure service is up

### "rfishbase package is required"

The `rfishbase` package is not installed.

**Solution:**
```r
install.packages("rfishbase")
```

### Slow query performance

First query may take longer due to data download/caching.

**Solution:**
- First query: 30-60 seconds is normal (downloading species database)
- Subsequent queries: Much faster (uses cached data)
- Consider caching results if querying same region multiple times

## Data Governance & Privacy

- This skill queries **public data** from FishBase
- No proprietary or sensitive data is handled
- Results can be freely shared and published
- Cite FishBase: Froese, R. and Pauly, D. (2024)

## Scientific Rigor

- This skill uses vectorized R operations (no loops)
- Handles missing/incomplete data explicitly
- Follows functional programming principles
- Provides complete provenance (timestamp, source, region)
- Returns reproducible results with same region name

## References

### FishBase
- **Citation:** Froese, R. and Pauly, D. (Eds.). 2024. FishBase. World Wide Web electronic publication. www.fishbase.org
- **Website:** https://www.fishbase.org
- **Access Date:** Current

### rfishbase Package
- **Documentation:** https://docs.ropensci.org/rfishbase/
- **Citation:** Chamberlain, S., Szocs, E. (2013). taxize - taxonomic search and retrieval in R. F1000Research, 2, 191.
- **GitHub:** https://github.com/ropensci/rfishbase

### Related Taxonomic Resources
- **World Register of Marine Species (WoRMS):** http://www.marinespecies.org/
- **Integrated Taxonomic Information System (ITIS):** https://www.itis.gov/
- **Taxonomic Database Working Group (TDWG):** https://www.tdwg.org/

## Testing

Run the test suite:

```r
Rscript -e "testthat::test_dir('agents/skills/data-processing/list-species-by-region/tests')"
```

**Note:** Tests require internet access to FishBase API. Tests marked with `skip_if_offline()` will be skipped if FishBase is unreachable.

---

**Last Updated:** 2026-08-28  
**Status:** ✅ Stable (v0.1.0)  
**Maintainer:** Marine Ecosystem Modeling Team  
**License:** Same as project (MIT)
