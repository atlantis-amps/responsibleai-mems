# Setting Up Agent Skills for Claude Code

This guide explains how to make the agent skills in this repository available to Claude Code.

## Quick Start

The skills system is already configured and discoverable. Claude Code can use these skills through two methods:

### Method 1: Direct Source (Recommended for Development)

Source skill implementations directly in R scripts:

```r
# Load a skill
source("agents/skills/data-processing/validate-ecosystem-data/implementation.R")

# Use the skill
result <- validate_ecosystem_data(
  input_data = my_data,
  species_reference = species_list,
  seed = 42
)
```

### Method 2: Via Skill Loader (Coming Soon)

A centralized skill loader will be available soon to simplify bulk skill loading:

```r
# Source the loader
source("agents/config/skill-loader.R")

# Load all skills in a category
load_category_skills("data-processing")

# Or load individual skills
load_skill("validate-ecosystem-data")
```

## Configuration Files

### 1. Skills Registry (`agents/skills-registry.json`)

Central manifest of all available skills:
- Lists all skill metadata (ID, name, description, version)
- Specifies dependencies (R packages)
- Defines skill categories and tags
- Indicates which skills are enabled

**Purpose:** Claude Code uses this to discover what skills are available.

### 2. Claude Code Settings (`~/.claude/settings.json`)

Configured to reference the local skills registry:

```json
{
  "extraKnownMarketplaces": {
    "responsibleai-mems-local": {
      "source": {
        "source": "file",
        "path": "/home/atlantis/responsibleai-mems/agents/skills-registry.json"
      }
    }
  }
}
```

### 3. Agent Configuration (`agents/config/agent-config.yaml`)

Template for R environment and skill loading:
- Specifies R version requirements
- Lists core packages (tidyverse, testthat, etc.)
- Defines data governance boundaries
- Controls test and documentation generation

**Usage:**
```bash
cp agents/config/agent-config.example.yaml agents/config/agent-config.yaml
# Edit agent-config.yaml to customize for your environment
```

## Skill Categories

Skills are organized by function:

| Category | Purpose | Examples |
|----------|---------|----------|
| `data-processing` | Data cleaning, validation, transformation | validate-ecosystem-data, list-species-by-region |
| `analysis` | Statistical and computational analysis | (in development) |
| `visualization` | Plotting, diagrams, reports | (in development) |
| `ecosystem-modeling` | Domain-specific marine models | (in development) |
| `utilities` | Shared helpers and configuration | (in development) |

## Adding a New Skill

1. **Create directory structure:**
   ```bash
   mkdir -p agents/skills/{category}/{skill-name}/tests
   ```

2. **Copy templates:**
   ```bash
   cp agents/templates/skill-template.yaml \
      agents/skills/{category}/{skill-name}/skill.yaml
   cp agents/templates/skill-template.R \
      agents/skills/{category}/{skill-name}/implementation.R
   cp agents/templates/test-skill-template.R \
      agents/skills/{category}/{skill-name}/tests/test-{skill-name}.R
   ```

3. **Customize files:**
   - Edit `skill.yaml` with metadata
   - Implement logic in `implementation.R`
   - Add tests in `tests/test-{skill-name}.R`
   - Write documentation in `README.md`

4. **Follow standards:**
   - Reference [SKILLS_GUIDE.md](docs/SKILLS_GUIDE.md) for development instructions
   - Ensure compliance with `CLAUDE.md` standards
   - Run tests: `Rscript -e "testthat::test_dir('agents/skills/{category}/{skill-name}/tests')"`

5. **Update registry:**
   Add entry to `agents/skills-registry.json`:
   ```json
   {
     "id": "skill-id",
     "name": "Skill Name",
     "category": "category",
     "version": "1.0.0",
     "description": "What it does",
     "path": "agents/skills/category/skill-id",
     "enabled": true
   }
   ```

## Project Standards

All skills must comply with standards defined in `CLAUDE.md`:

### Code Quality
- ✅ Use `tidyverse` pipe (`%>%`)
- ✅ Vectorized operations (no explicit loops)
- ❌ No global assignment (`<<-`)
- ❌ No `attach()` calls
- ✅ Pure functions with explicit returns

### Testing
- ✅ Full test coverage with `testthat`
- ✅ Edge case tests (NA, Inf, NaN, empty inputs)
- ✅ Floating-point tolerance (`tolerance = 1e-6`)
- ✅ Explicit NA/NaN/Inf handling
- ✅ Reproducibility with seed parameters

### Documentation
- ✅ Roxygen2 tags
- ✅ README.md with examples
- ✅ Parameter descriptions
- ✅ Scientific references

### Data Governance
- ✅ No PII in code/comments
- ✅ Use certified data sources only
- ✅ Respect data boundaries
- ✅ Protect frozen baseline data

## Troubleshooting

### Skill doesn't appear in Claude Code

1. **Check registry:** Ensure skill is listed in `agents/skills-registry.json`
2. **Check file:** Verify `skills-registry.json` is valid JSON:
   ```bash
   Rscript -e "jsonlite::fromJSON('agents/skills-registry.json')"
   ```
3. **Check settings:** Verify Claude Code settings point to the registry:
   ```bash
   cat ~/.claude/settings.json | grep responsibleai-mems-local
   ```

### Skill fails to load

1. **Check dependencies:** Install all required packages:
   ```bash
   Rscript -e "renv::restore()"
   ```
2. **Check syntax:** Source the implementation directly:
   ```bash
   Rscript agents/skills/{category}/{skill-name}/implementation.R
   ```
3. **Run tests:** Check for errors:
   ```bash
   Rscript -e "testthat::test_dir('agents/skills/{category}/{skill-name}/tests')"
   ```

### Tests fail

1. **Run with verbose output:** `testthat::test_dir(..., reporter = "tap")`
2. **Check floating-point precision:** Use `tolerance = 1e-6`
3. **Verify R version:** Must be ≥ 4.0.0

## Resources

- **Development Guide:** [docs/SKILLS_GUIDE.md](docs/SKILLS_GUIDE.md)
- **Architecture Overview:** [docs/OVERVIEW.md](docs/OVERVIEW.md)
- **Project Standards:** [../../CLAUDE.md](../../CLAUDE.md)
- **Templates:** [templates/](templates/)
- **Example Implementation:** [skills/data-processing/validate-ecosystem-data/](skills/data-processing/validate-ecosystem-data/)

## Integration with Workflows

### In R Analysis Scripts

```r
# Load skill
source("agents/skills/data-processing/validate-ecosystem-data/implementation.R")

# Use in pipeline
clean_data <- raw_data %>%
  validate_ecosystem_data(species_ref = species_list, seed = 42) %>%
  .$cleaned_data
```

### Via Claude Code Assistant

```
@Claude Please validate my ecosystem data using the validate-ecosystem-data skill.
```

Claude will automatically source and execute the appropriate skill function.

## Getting Help

- **Questions about skills?** Check [SKILLS_GUIDE.md](docs/SKILLS_GUIDE.md)
- **Questions about project standards?** See [CLAUDE.md](../../CLAUDE.md)
- **Questions about specific skill?** Read its `README.md`

---

**Last Updated:** 2026-08-28  
**Status:** ✅ Ready for use
