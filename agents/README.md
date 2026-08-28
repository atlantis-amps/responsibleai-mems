# Agent Skills Repository

This directory contains Claude Code agent skill implementations for the Responsible AI in Marine Ecosystem Modeling project.

## Directory Structure

```
agents/
├── skills/                      # Skill implementations
│   ├── data-processing/         # Data cleaning, validation, and preprocessing
│   ├── analysis/                # Statistical and computational analysis
│   ├── visualization/           # Plotting, visualization, and reporting
│   ├── ecosystem-modeling/      # Marine ecosystem-specific models and functions
│   └── utilities/               # Helper functions and shared utilities
├── templates/                   # Skill creation templates
├── config/                      # Configuration files for agents
└── docs/                        # Documentation and guides
```

## Skill Naming Convention

Each skill follows this structure:
```
skills/{category}/{skill-name}/
├── skill.yaml              # Skill metadata and definition
├── implementation.R        # Core R implementation
├── tests/
│   └── test-{skill-name}.R # Test suite
└── README.md              # Skill documentation
```

## Quick Start

1. Browse existing skills in `skills/{category}/`
2. Copy a template from `templates/` to start a new skill
3. Define skill metadata in `skill.yaml`
4. Implement logic in `implementation.R`
5. Add tests in `tests/`
6. Document in `README.md`

## Project Standards

All agent skills must comply with the project's standards defined in `CLAUDE.md`:
- Use `tidyverse` or `data.table` for data operations
- Follow functional programming principles (no global assignment with `<<-`)
- Include comprehensive test coverage using `testthat`
- Preserve reproducibility with explicit seed parameters
- Maintain data governance and privacy standards

For more details, see `/agents/docs/SKILLS_GUIDE.md`
