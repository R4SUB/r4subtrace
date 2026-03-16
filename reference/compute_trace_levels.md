# Compute Trace Levels for ADaM Variables

Assigns a traceability level (L0–L3) to each ADaM variable in the trace
model based on available mapping, derivation text, and confidence
scores.

## Usage

``` r
compute_trace_levels(trace_model)
```

## Arguments

- trace_model:

  A `trace_model` object from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

## Value

A tibble with columns: `adam_dataset`, `adam_var`, `trace_level`,
`has_mapping`, `has_derivation_text`, `n_candidates`, `max_confidence`.

## Details

Trace levels:

- **L0**: No mapping and no derivation text.

- **L1**: Derivation text present but no SDTM mapping.

- **L2**: Mapping to SDTM variable/domain exists.

- **L3**: Mapping exists AND (confidence \>= threshold OR derivation
  text present alongside mapping).

## Examples

``` r
adam_meta <- data.frame(
  dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGE", "AGEGR1"),
  label = c("Study ID", "Unique Subject ID", "Age", "Age Group")
)
sdtm_meta <- data.frame(
  dataset = "DM", variable = c("STUDYID", "USUBJID", "AGE"),
  label = c("Study ID", "Unique Subject ID", "Age")
)
map <- data.frame(
  adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID", "AGE"),
  sdtm_domain = "DM",   sdtm_var = c("STUDYID", "USUBJID", "AGE"),
  confidence = c(1.0, 1.0, 0.9)
)
tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
compute_trace_levels(tm)
#> # A tibble: 4 × 7
#>   adam_dataset adam_var trace_level has_mapping has_derivation_text n_candidates
#>   <chr>        <chr>          <int> <lgl>       <lgl>                      <int>
#> 1 ADSL         STUDYID            3 TRUE        TRUE                           1
#> 2 ADSL         USUBJID            3 TRUE        TRUE                           1
#> 3 ADSL         AGE                3 TRUE        TRUE                           1
#> 4 ADSL         AGEGR1             1 FALSE       TRUE                           0
#> # ℹ 1 more variable: max_confidence <dbl>
```
