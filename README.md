# r4subtrace

**r4subtrace** is the traceability engine in the **R4SUB** ecosystem. It quantifies and explains **end-to-end traceability** between clinical submission artifacts -- primarily **ADaM outputs <-> derivations <-> SDTM sources <-> specs <-> code** -- and converts trace evidence into standardized **R4SUB Evidence Table** rows (from `r4subcore`).

It focuses on answering one question:

> **Can we prove where each analysis variable/value came from, and can a reviewer follow it?**

## Why r4subtrace?

In real submissions, issues are rarely "a single failed rule." Many are trace failures:
- Missing or ambiguous derivation documentation
- ADaM variable not linkable to SDTM sources
- Mismatch between spec and what code produces
- Inconsistent naming across specs, define.xml, and datasets
- Reviewer cannot reproduce or validate lineage

`r4subtrace` formalizes traceability as **evidence + measurable indicators**.

## What r4subtrace measures

### Traceability levels
- **L0 -- None:** no linkage available
- **L1 -- Spec-only:** ADaM spec defines derivation but no code mapping
- **L2 -- Spec + source mapping:** ADaM var mapped to SDTM vars/domains
- **L3 -- Spec + code mapping:** mapping exists with high confidence or derivation text

## Installation

```r
pak::pak(c("R4SUB/r4subcore", "R4SUB/r4subtrace"))
```

## Quick start

### 1) Create run context

```r
library(r4subcore)
library(r4subtrace)

ctx <- r4sub_run_context(study_id = "ABC123", environment = "DEV")
```

### 2) Load metadata

```r
adam_meta <- read.csv("adam_metadata.csv")  # columns: dataset, variable, label, type
sdtm_meta <- read.csv("sdtm_metadata.csv")  # same structure

map <- read.csv("trace_map.csv")
# recommended columns:
# adam_dataset, adam_var, sdtm_domain, sdtm_var, derivation_text(optional), confidence(optional)
```

### 3) Build trace model and evidence

```r
tm <- build_trace_model(
  adam_meta = adam_meta,
  sdtm_meta = sdtm_meta,
  mapping   = map
)

ev <- trace_model_to_evidence(tm, ctx = ctx, source_name = "r4subtrace", source_version = "0.1.0")

validate_evidence(ev)
evidence_summary(ev)
```

### 4) Compute trace coverage score

```r
ind <- trace_indicator_scores(ev)
ind
```

## Core objects

### Trace Model

A list with:

* `nodes`: tidy table of assets (dataset/variable/spec/program)
* `edges`: tidy table of relationships + confidence
* `diagnostics`: issues found (orphans, ambiguities, conflicts)

### Trace Evidence

Evidence rows are emitted for:

* each ADaM variable trace level
* each orphan/ambiguity/conflict
* aggregate coverage metrics

## Indicators

* `TRACE_VAR_COVERAGE_L2PLUS`: proportion of ADaM variables with L2+ trace
* `TRACE_VAR_COVERAGE_L3PLUS`: proportion with L3+ trace
* `TRACE_ORPHAN_VAR_COUNT`: orphan ADaM vars with no SDTM mapping
* `TRACE_AMBIGUOUS_MAPPING_COUNT`: vars mapped to multiple SDTM sources
* `TRACE_MEAN_TRACE_LEVEL`: mean trace level across all ADaM variables

## Design principles

* **Graph-first:** traceability is a graph problem
* **Evidence-first:** all conclusions are backed by explicit evidence rows
* **Tool-agnostic:** can ingest mapping from any source format
* **Reviewer-centric:** emphasize explainability, not just metrics

## License

MIT
