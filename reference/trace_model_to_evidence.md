# Convert Trace Model to R4SUB Evidence

Emits evidence rows compatible with
[`r4subcore::validate_evidence()`](https://rdrr.io/pkg/r4subcore/man/validate_evidence.html)
for each ADaM variable's trace level, plus diagnostic rows for orphans,
ambiguities, and conflicts.

## Usage

``` r
trace_model_to_evidence(
  trace_model,
  ctx,
  source_name = "r4subtrace",
  source_version = NULL
)
```

## Arguments

- trace_model:

  A `trace_model` object from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- ctx:

  An `r4sub_run_context` from
  [`r4subcore::r4sub_run_context()`](https://rdrr.io/pkg/r4subcore/man/r4sub_run_context.html).

- source_name:

  Character; the name of the evidence source.

- source_version:

  Character or `NULL`; version of the source.

## Value

A data.frame of evidence rows passing
[`r4subcore::validate_evidence()`](https://rdrr.io/pkg/r4subcore/man/validate_evidence.html).

## Examples

``` r
library(r4subcore)
ctx <- r4sub_run_context(study_id = "TEST001", environment = "DEV")
#> ℹ Run context created: "R4S-20260713141925-ombeu7fd"
adam_meta <- data.frame(
  dataset = "ADSL", variable = c("STUDYID", "AGE"),
  label = c("Study ID", "Age")
)
sdtm_meta <- data.frame(
  dataset = "DM", variable = c("STUDYID", "AGE"),
  label = c("Study ID", "Age")
)
map <- data.frame(
  adam_dataset = "ADSL", adam_var = c("STUDYID", "AGE"),
  sdtm_domain = "DM",   sdtm_var = c("STUDYID", "AGE")
)
tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
ev <- trace_model_to_evidence(tm, ctx = ctx)
#> ✔ Evidence table created: 2 rows
r4subcore::validate_evidence(ev)
```
