#' Skill Loader Utility
#'
#' Utilities for discovering, loading, and managing agent skills.
#'
#' @details
#' This module provides functions to:
#' - Discover available skills from the skill registry
#' - Load skill implementations dynamically
#' - Validate skill metadata
#' - List skills by category
#'
#' @examples
#' \dontrun{
#'   source("agents/config/skill-loader.R")
#'
#'   # List all available skills
#'   list_all_skills()
#'
#'   # List skills in a category
#'   list_category_skills("data-processing")
#'
#'   # Load a single skill
#'   load_skill("validate-ecosystem-data")
#'
#'   # Load all skills in a category
#'   load_category_skills("data-processing")
#'
#'   # Get skill information
#'   get_skill_info("validate-ecosystem-data")
#' }
#'
#' @keywords internal
NULL

# Private: Registry cache
.skill_registry_cache <- NULL

#' Load Skill Registry
#'
#' Internal function to load and cache the skill registry.
#'
#' @return List containing registry metadata and skills
#' @keywords internal
.load_registry <- function() {
  if (!is.null(.skill_registry_cache)) {
    return(.skill_registry_cache)
  }

  registry_path <- file.path(
    dirname(dirname(dirname(rstudioapi::getSourceEditorContext()$path))),
    "agents/skills-registry.json"
  )

  # Fallback: construct path from current working directory
  if (!file.exists(registry_path)) {
    registry_path <- "agents/skills-registry.json"
  }

  if (!file.exists(registry_path)) {
    stop(
      "Skill registry not found at: ", registry_path,
      call. = FALSE
    )
  }

  registry <- jsonlite::fromJSON(registry_path)
  .skill_registry_cache <<- registry
  registry
}

#' List All Skills
#'
#' Display all available skills in the registry.
#'
#' @param detailed If TRUE, show full details; if FALSE, show summary
#'
#' @return Invisibly returns a data frame of skills
#' @export
list_all_skills <- function(detailed = FALSE) {
  registry <- .load_registry()

  skills_df <- do.call(rbind, lapply(registry$skills, function(skill) {
    data.frame(
      id = skill$id,
      name = skill$name,
      category = skill$category,
      version = skill$version,
      enabled = skill$enabled,
      stringsAsFactors = FALSE
    )
  }))

  if (detailed) {
    print(skills_df)
    cat("\nFor detailed information on a skill, use:\n")
    cat("  get_skill_info('<skill-id>')\n")
  } else {
    cat("Available Skills:\n")
    cat("================\n\n")

    by_category <- split(skills_df, skills_df$category)

    for (category in names(by_category)) {
      cat(paste0(category, ":\n"))
      skills <- by_category[[category]]
      for (i in seq_len(nrow(skills))) {
        status <- if (skills$enabled[i]) "✓" else "✗"
        cat(sprintf("  [%s] %s (%s)\n", status, skills$id[i], skills$version[i]))
      }
      cat("\n")
    }
  }

  invisible(skills_df)
}

#' List Skills by Category
#'
#' Display skills in a specific category.
#'
#' @param category Category name (e.g., "data-processing", "analysis")
#'
#' @return Data frame of skills in that category
#' @export
list_category_skills <- function(category) {
  registry <- .load_registry()

  skills_df <- do.call(rbind, lapply(registry$skills, function(skill) {
    data.frame(
      id = skill$id,
      name = skill$name,
      version = skill$version,
      enabled = skill$enabled,
      stringsAsFactors = FALSE
    )
  }))

  category_skills <- skills_df[skills_df$category == category, ]

  if (nrow(category_skills) == 0) {
    stop(
      "No skills found in category: ", category,
      call. = FALSE
    )
  }

  cat(sprintf("Skills in '%s':\n", category))
  cat("================\n\n")
  for (i in seq_len(nrow(category_skills))) {
    status <- if (category_skills$enabled[i]) "✓" else "✗"
    cat(sprintf(
      "  [%s] %s (%s)\n",
      status,
      category_skills$id[i],
      category_skills$version[i]
    ))
  }

  invisible(category_skills)
}

#' Get Skill Information
#'
#' Display detailed information about a specific skill.
#'
#' @param skill_id Skill identifier
#'
#' @return List with skill metadata (invisibly)
#' @export
get_skill_info <- function(skill_id) {
  registry <- .load_registry()

  skill <- NULL
  for (s in registry$skills) {
    if (s$id == skill_id) {
      skill <- s
      break
    }
  }

  if (is.null(skill)) {
    stop(
      "Skill not found: ", skill_id,
      call. = FALSE
    )
  }

  cat(sprintf("Skill: %s\n", skill$name))
  cat(sprintf("ID: %s\n", skill$id))
  cat(sprintf("Category: %s\n", skill$category))
  cat(sprintf("Version: %s\n", skill$version))
  cat(sprintf("Status: %s\n", if (skill$enabled) "Enabled" else "Disabled"))
  cat(sprintf("Description: %s\n\n", skill$description))

  if (length(skill$tags) > 0) {
    cat(sprintf("Tags: %s\n\n", paste(skill$tags, collapse = ", ")))
  }

  if (length(skill$dependencies) > 0) {
    cat("Dependencies:\n")
    for (dep in skill$dependencies) {
      cat(sprintf("  - %s\n", dep))
    }
    cat("\n")
  }

  cat(sprintf("Path: %s\n", skill$path))
  cat(sprintf("Implementation: %s\n", skill$entry_point))
  cat(sprintf("Documentation: %s\n", file.path(skill$path, skill$documentation)))

  # Check if documentation file exists
  doc_path <- file.path(skill$path, skill$documentation)
  if (file.exists(doc_path)) {
    cat("\n--- README ---\n")
    readLines(doc_path) %>%
      head(50) %>%  # Show first 50 lines
      cat(sep = "\n")
    cat("\n... (use cat(readLines('", doc_path, "')) to view full documentation)\n")
  }

  invisible(skill)
}

#' Load Skill Implementation
#'
#' Load a skill's R implementation into the current environment.
#'
#' @param skill_id Skill identifier
#' @param env Environment to load skill into (default: parent environment)
#'
#' @return Invisibly returns the skill metadata
#' @export
load_skill <- function(skill_id, env = parent.frame()) {
  registry <- .load_registry()

  skill <- NULL
  for (s in registry$skills) {
    if (s$id == skill_id) {
      skill <- s
      break
    }
  }

  if (is.null(skill)) {
    stop(
      "Skill not found: ", skill_id,
      call. = FALSE
    )
  }

  if (!skill$enabled) {
    warning(
      "Skill is disabled: ", skill_id,
      call. = FALSE
    )
  }

  # Verify dependencies are installed
  .check_dependencies(skill$dependencies)

  # Source the implementation
  impl_path <- file.path(skill$path, "implementation.R")

  if (!file.exists(impl_path)) {
    stop(
      "Implementation file not found: ", impl_path,
      call. = FALSE
    )
  }

  message(sprintf("Loading skill: %s (%s)", skill$name, skill$version))
  source(impl_path, local = env)
  invisible(skill)
}

#' Load All Skills in Category
#'
#' Load all R implementations from a skill category.
#'
#' @param category Category name
#' @param env Environment to load skills into (default: parent environment)
#'
#' @return Invisibly returns list of loaded skill metadata
#' @export
load_category_skills <- function(category, env = parent.frame()) {
  registry <- .load_registry()

  category_skills <- Filter(function(s) s$category == category, registry$skills)

  if (length(category_skills) == 0) {
    stop(
      "No skills found in category: ", category,
      call. = FALSE
    )
  }

  message(sprintf("Loading %d skills from '%s'...", length(category_skills), category))

  loaded <- lapply(category_skills, function(skill) {
    load_skill(skill$id, env = env)
  })

  invisible(loaded)
}

#' Check Dependencies
#'
#' Verify that all required packages are installed.
#'
#' @param dependencies Character vector of package names
#'
#' @keywords internal
.check_dependencies <- function(dependencies) {
  missing <- character(0)

  for (pkg in dependencies) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing <- c(missing, pkg)
    }
  }

  if (length(missing) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing, collapse = ", "),
      "\nInstall with: renv::install(c('",
      paste(missing, collapse = "', '"),
      "'))",
      call. = FALSE
    )
  }
}

#' List Available Categories
#'
#' Show all skill categories defined in the registry.
#'
#' @return Character vector of category names
#' @export
list_categories <- function() {
  registry <- .load_registry()
  names(registry$skill_categories)
}

#' Show Standards Compliance
#'
#' Display the standards that skills must comply with.
#'
#' @export
show_standards <- function() {
  registry <- .load_registry()

  cat("Project Standards Compliance\n")
  cat("=============================\n\n")

  for (name in names(registry$standards_compliance)) {
    cat(sprintf("%s: %s\n", name, registry$standards_compliance[[name]]))
  }

  cat("\n--- More Information ---\n")
  cat("See CLAUDE.md and agents/docs/SKILLS_GUIDE.md for details.\n")
}
