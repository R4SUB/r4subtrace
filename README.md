# r4subtrace

<!-- badges: start -->
[![R-CMD-check](https://github.com/R4SUB/r4subtrace/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/R4SUB/r4subtrace/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/r4subtrace)](https://CRAN.R-project.org/package=r4subtrace)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/r4subtrace)](https://CRAN.R-project.org/package=r4subtrace)
[![r-universe](https://r4sub.r-universe.dev/badges/r4subtrace)](https://r4sub.r-universe.dev/r4subtrace)
<!-- badges: end -->

**r4subtrace** is the traceability engine in the R4SUB ecosystem. It quantifies end-to-end traceability between clinical submission artifacts (ADaM outputs, derivations, SDTM sources, specs, and code) and converts trace evidence into standardized R4SUB evidence rows.

> Can we prove where each analysis variable came from, and can a reviewer follow it?

## Installation

```r
install.packages("r4subtrace")
```

Development version:

```r
pak::pak(c("R4SUB/r4subcore", "R4SUB/r4subtrace"))
```

## Traceability Levels

| Level | Name | Description |
|---|---|---|
| L0 | None | No linkage available |
| L1 | Spec-only | ADaM spec defines derivation, no code mapping |
| L2 | Spec + source | ADaM variable mapped to SDTM variables/domains |
| L3 | Spec + code | Mapping with high confidence or derivation text |

## Quick Start

```r
library(r4subcore)
library(r4subtrace)

ctx <- r4sub_run_context(study_id = "ABC123", environment = "DEV")

# Build a trace model from metadata and mapping tables
tm <- build_trace_model(
  adam_meta = adam_metadata,
  sdtm_meta = sdtm_metadata,
  mapping   = trace_mapping
)

# Emit evidence rows
ev <- trace_model_to_evidence(tm, ctx = ctx,
                              source_name = "r4subtrace",
                              source_version = "0.1.0")

validate_evidence(ev)

# Indicator scores
ind <- trace_indicator_scores(ev)
```

## Trace Indicators

| Indicator | Description |
|---|---|
| `TRACE_VAR_COVERAGE_L2PLUS` | Proportion of ADaM variables with L2+ trace |
| `TRACE_VAR_COVERAGE_L3PLUS` | Proportion with L3+ trace |
| `TRACE_ORPHAN_VAR_COUNT` | ADaM variables with no SDTM mapping |
| `TRACE_AMBIGUOUS_MAPPING_COUNT` | Variables mapped to multiple SDTM sources |
| `TRACE_MEAN_TRACE_LEVEL` | Mean trace level across all ADaM variables |

## Key Functions

| Function | Purpose |
|---|---|
| `trace_config_default()` | Default traceability configuration |
| `build_trace_model()` | Build a trace graph from metadata and mappings |
| `compute_trace_levels()` | Assign L0–L3 trace levels per ADaM variable |
| `trace_model_to_evidence()` | Emit r4subcore-compatible evidence rows |
| `trace_indicator_scores()` | Compute trace indicator scores |
| `validate_mapping()` | Validate a mapping table for required columns |
| `validate_metadata()` | Validate ADaM/SDTM metadata tables |

## Design Principles

- **Graph-first:** traceability is a graph problem
- **Evidence-first:** all conclusions are backed by explicit evidence rows
- **Tool-agnostic:** ingest mappings from any source format
- **Reviewer-centric:** emphasize explainability, not just metrics

## Maintained by

R4SUB is part of the open-source work of [TechWorksLab](https://techworkslab.com) - clinical programming and regulatory submissions. Maintainer: Pawan Rama Mali.

## License

MIT
