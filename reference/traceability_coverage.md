# Traceability Coverage by ADaM Dataset

Summarizes how much of each ADaM dataset is traced back to SDTM. A
variable counts as traced when its trace level reaches
`traced_min_level`. The default of `2` treats an existing SDTM mapping
(level L2) as traced.

## Usage

``` r
traceability_coverage(trace_model, traced_min_level = 2L)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- traced_min_level:

  The minimum trace level that counts as traced, an integer in `0:3`.
  Default `2`.

## Value

A tibble with one row per ADaM dataset: `adam_dataset`, `n_variables`,
`n_traced`, `n_untraced`, `pct_traced`, and `untraced_vars` (a
comma-separated list, empty when the dataset is fully traced).

## Examples

``` r
adam_meta <- data.frame(
  dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGEGR1"),
  label = c("Study ID", "Unique Subject ID", NA)
)
sdtm_meta <- data.frame(dataset = "DM", variable = c("STUDYID", "USUBJID"))
map <- data.frame(
  adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID"),
  sdtm_domain = "DM", sdtm_var = c("STUDYID", "USUBJID"),
  confidence = c(1, 1)
)
tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
traceability_coverage(tm)
#> # A tibble: 1 × 6
#>   adam_dataset n_variables n_traced n_untraced pct_traced untraced_vars
#>   <chr>              <int>    <int>      <int>      <dbl> <chr>        
#> 1 ADSL                   3        2          1       66.7 AGEGR1       
```
