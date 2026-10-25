# Export a Traceability Coverage Report

Produces the coverage table an ADRG appendix needs: per-dataset
traceability percentages, the untraced variables, and an overall summary
row. The report can be returned as a data.frame or written to CSV or
Excel for inclusion in a submission package.

## Usage

``` r
export_traceability_report(
  trace_model,
  format = c("data.frame", "csv", "xlsx"),
  path = NULL,
  traced_min_level = 2L
)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- format:

  One of `"data.frame"`, `"csv"`, or `"xlsx"`.

- path:

  Output file path, required for `"csv"` and `"xlsx"`.

- traced_min_level:

  The minimum trace level that counts as traced. Passed to
  [`traceability_coverage()`](https://r4sub.github.io/r4subtrace/reference/traceability_coverage.md).

## Value

For `"data.frame"`, the report tibble. For `"csv"` and `"xlsx"`, the
report is written to `path` and the path is returned invisibly.

## Examples

``` r
adam_meta <- data.frame(
  dataset = "ADSL", variable = c("STUDYID", "AGEGR1"),
  label = c("Study ID", NA)
)
sdtm_meta <- data.frame(dataset = "DM", variable = "STUDYID")
map <- data.frame(
  adam_dataset = "ADSL", adam_var = "STUDYID",
  sdtm_domain = "DM", sdtm_var = "STUDYID", confidence = 1
)
tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
export_traceability_report(tm)
#> # A tibble: 2 × 6
#>   adam_dataset n_variables n_traced n_untraced pct_traced untraced_vars
#>   <chr>              <int>    <int>      <int>      <dbl> <chr>        
#> 1 ADSL                   2        1          1         50 "AGEGR1"     
#> 2 OVERALL                2        1          1         50 ""           
```
