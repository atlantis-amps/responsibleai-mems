#' List Fish Species by Marine Region
#'
#' @description
#' Query FishBase database to retrieve fish species present in a specified
#' marine region with complete taxonomic classification.
#'
#' @param region A character string specifying the marine region name.
#'   Examples: "North Atlantic", "Mediterranean", "Coral Triangle", "North Sea"
#' @param include_missing_taxonomy Logical. If FALSE (default), excludes species
#'   with incomplete taxonomy information.
#' @param simplify Logical. If TRUE (default), returns simplified output with
#'   Species, Genus, Family, and Order columns only.
#' @param seed Optional seed for reproducibility. Defaults to NULL.
#'
#' @return
#' A list containing:
#'   - `species_data`: Data frame with species and taxonomy information
#'   - `summary`: List with summary statistics (total species, families, orders)
#'   - `region_queried`: The region name that was queried
#'   - `query_timestamp`: When the query was executed
#'   - `data_source`: Information about FishBase version used
#'
#' @details
#' This function queries the FishBase database using the rfishbase package.
#'
#' The function:
#' 1. Queries species distribution data from FishBase by region
#' 2. Retrieves complete taxonomy for each species
#' 3. Validates data completeness
#' 4. Generates diversity statistics
#'
#' **Important notes:**
#' - Requires internet access to reach FishBase API
#' - First query may take longer due to data download/caching
#' - Region names should match FishBase conventions
#' - Some species may have incomplete or uncertain taxonomy in FishBase
#'
#' @examples
#' \dontrun{
#'   # List species in Mediterranean
#'   result <- list_species_by_region("Mediterranean")
#'   print(result$species_data)
#'   print(result$summary)
#'
#'   # Include species with incomplete taxonomy
#'   result <- list_species_by_region(
#'     "North Atlantic",
#'     include_missing_taxonomy = TRUE
#'   )
#'
#'   # Get full output with additional details
#'   result <- list_species_by_region("Coral Triangle", simplify = FALSE)
#' }
#'
#' @export
list_species_by_region <- function(region,
                                    include_missing_taxonomy = FALSE,
                                    simplify = TRUE,
                                    seed = NULL) {

  # Input validation
  if (!is.character(region) || length(region) != 1) {
    stop("region must be a single character string", call. = FALSE)
  }

  if (nchar(trimws(region)) == 0) {
    stop("region cannot be an empty string", call. = FALSE)
  }

  if (!is.logical(include_missing_taxonomy)) {
    stop("include_missing_taxonomy must be logical (TRUE/FALSE)", call. = FALSE)
  }

  if (!is.logical(simplify)) {
    stop("simplify must be logical (TRUE/FALSE)", call. = FALSE)
  }

  # Check if rfishbase is available
  if (!requireNamespace("rfishbase", quietly = TRUE)) {
    stop(
      "rfishbase package is required. Install with:\n",
      'install.packages("rfishbase")',
      call. = FALSE
    )
  }

  # Query species from the specified region
  tryCatch({
    # Use rfishbase to query species by ecosystem/region
    # The function queries species presence by region/country
    species_list <- query_fishbase_region(region)

    if (is.null(species_list) || nrow(species_list) == 0) {
      warning("No species found for region: ", region, call. = FALSE)
      return(list(
        species_data = data.frame(
          Species = character(),
          Genus = character(),
          Family = character(),
          Order = character()
        ),
        summary = list(
          total_species = 0,
          total_families = 0,
          total_orders = 0,
          region = region,
          message = "No species found"
        ),
        region_queried = region,
        query_timestamp = Sys.time(),
        data_source = "FishBase (rfishbase)"
      ))
    }

    # Filter for data completeness if requested
    if (!include_missing_taxonomy) {
      species_list <- species_list %>%
        dplyr::filter(
          !is.na(Order) & nchar(Order) > 0,
          !is.na(Family) & nchar(Family) > 0,
          !is.na(Genus) & nchar(Genus) > 0,
          !is.na(Species) & nchar(Species) > 0
        )

      if (nrow(species_list) == 0) {
        warning(
          "No species with complete taxonomy found for region: ",
          region,
          call. = FALSE
        )
      }
    }

    # Simplify output if requested
    if (simplify) {
      species_output <- species_list %>%
        dplyr::select(Species, Genus, Family, Order) %>%
        dplyr::arrange(Order, Family, Genus, Species) %>%
        dplyr::distinct()
    } else {
      species_output <- species_list %>%
        dplyr::arrange(Order, Family, Genus, Species) %>%
        dplyr::distinct()
    }

    # Generate summary statistics
    summary_stats <- list(
      total_species = nrow(species_output),
      unique_families = length(unique(species_output$Family)),
      unique_orders = length(unique(species_output$Order)),
      families = sort(unique(species_output$Family)),
      orders = sort(unique(species_output$Order)),
      species_per_family = species_output %>%
        dplyr::group_by(Family) %>%
        dplyr::summarise(count = dplyr::n(), .groups = "drop") %>%
        dplyr::arrange(dplyr::desc(count)) %>%
        as.data.frame(),
      species_per_order = species_output %>%
        dplyr::group_by(Order) %>%
        dplyr::summarise(count = dplyr::n(), .groups = "drop") %>%
        dplyr::arrange(dplyr::desc(count)) %>%
        as.data.frame()
    )

    return(list(
      species_data = species_output,
      summary = summary_stats,
      region_queried = region,
      query_timestamp = Sys.time(),
      data_source = "FishBase (rfishbase)"
    ))

  }, error = function(e) {
    stop(
      "Error querying FishBase for region '",
      region,
      "': ",
      conditionMessage(e),
      call. = FALSE
    )
  })
}

#' Query FishBase Region Data
#'
#' @description
#' Internal function to query FishBase ecosystem/region data and retrieve
#' species present in that region with their taxonomy.
#'
#' @param region Region name to query
#'
#' @return
#' Data frame with species and taxonomy columns, or NULL if not found
#'
#' @keywords internal
#' @noRd
query_fishbase_region <- function(region) {
  tryCatch({
    # Query ecosystem data from FishBase
    # This uses rfishbase::ecosystem() to get region-specific data
    ecosystem_data <- rfishbase::ecosystem(
      fields = c(
        "Species",
        "Genus",
        "Family",
        "Order",
        "Ecosystem"
      )
    )

    if (is.null(ecosystem_data) || nrow(ecosystem_data) == 0) {
      return(NULL)
    }

    # Filter for the specified region (case-insensitive)
    region_pattern <- paste0("(?i)", region)

    filtered_data <- ecosystem_data %>%
      dplyr::filter(
        !is.na(Ecosystem),
        grepl(region_pattern, Ecosystem, ignore.case = TRUE)
      ) %>%
      dplyr::select(Species, Genus, Family, Order) %>%
      dplyr::distinct()

    if (nrow(filtered_data) == 0) {
      # If no direct region match, try to query all species and note limitation
      warning(
        "Region '",
        region,
        "' not found in ecosystem data. ",
        "Consider using alternative region names or check FishBase documentation.",
        call. = FALSE
      )
      return(NULL)
    }

    return(filtered_data)

  }, error = function(e) {
    stop(
      "Failed to query FishBase ecosystem data: ",
      conditionMessage(e),
      call. = FALSE
    )
  })
}

#' Format Species for Display
#'
#' @description
#' Helper function to format species names and taxonomy for display.
#'
#' @param species_data Data frame with species information
#' @param format Type of format ("simple", "scientific", "full")
#'
#' @return
#' Formatted data frame
#'
#' @keywords internal
#' @noRd
format_species_display <- function(species_data, format = "simple") {
  if (nrow(species_data) == 0) {
    return(species_data)
  }

  switch(format,
    simple = {
      species_data %>%
        dplyr::mutate(
          ScientificName = paste(Genus, Species)
        ) %>%
        dplyr::select(ScientificName, Family, Order)
    },
    scientific = {
      species_data %>%
        dplyr::mutate(
          FullTaxonomy = paste(Order, "|", Family, "|", Genus, "|", Species)
        )
    },
    full = {
      species_data
    },
    species_data
  )
}
