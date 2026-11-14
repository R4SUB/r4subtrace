# Export an Impact Analysis Report

Writes the result of
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
as a report for a change-control record: every affected downstream
variable, its distance from the change, and the derivation path back to
it, with the changed variable recorded in a leading column. The report
can be returned as a data.frame or written to CSV or Excel, mirroring
[`export_traceability_report()`](https://r4sub.github.io/r4subtrace/reference/export_traceability_report.md).

## Usage

``` r
export_impact_report(
  impact,
  format = c("data.frame", "csv", "xlsx"),
  path = NULL
)
```

## Arguments

- impact:

  A tibble returned by
  [`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md),
  with columns `dataset`, `variable`, `role`, `depth`, and `path`.

- format:

  One of `"data.frame"`, `"csv"`, or `"xlsx"`.

- path:

  Output file path, required for `"csv"` and `"xlsx"`.

## Value

For `"data.frame"`, the report tibble (a `changed` column followed by
the impact detail). For `"csv"` and `"xlsx"`, the report is written to
`path` and the path is returned invisibly.

## Examples

``` r
adam <- data.frame(
  dataset = c("ADSL", "ADAE"), variable = c("AGE", "AAGE"),
  label = c("Age", "Analysis Age")
)
sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
map <- data.frame(
  adam_dataset = "ADSL", adam_var = "AGE",
  sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
)
tm <- build_trace_model(adam, sdtm, mapping = map)
deriv <- data.frame(
  from_dataset = "ADAE", from_var = "AAGE",
  to_dataset = "ADSL", to_var = "AGE"
)
imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv)
export_impact_report(imp)
#> # A tibble: 2 × 6
#>   changed dataset variable role  depth path                           
#>   <chr>   <chr>   <chr>    <chr> <int> <chr>                          
#> 1 DM.AGE  ADSL    AGE      adam      1 ADSL.AGE -> DM.AGE             
#> 2 DM.AGE  ADAE    AAGE     adam      2 ADAE.AAGE -> ADSL.AGE -> DM.AGE
```
