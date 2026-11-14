# Report Unused SDTM Source Variables

The mirror image of orphan detection. Orphans are ADaM variables that
trace to nothing; `sdtm_utilization()` asks the opposite question of the
sources: which SDTM variables are referenced by no ADaM variable at all?
These are the dead or unused sources in a submission, the columns a
derivation never reads.

## Usage

``` r
sdtm_utilization(trace_model, adam_derivations = NULL)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- adam_derivations:

  Optional data.frame of ADaM-to-ADaM derivations with columns
  `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).
  Accepted for parity; it does not change which SDTM variables are
  considered used.

## Value

A tibble with one row per SDTM variable: `dataset`, `variable`,
`used_count` (how many ADaM variables map to it), and `referenced`
(whether `used_count` is above zero). Unused sources are listed first,
then by dataset and variable. Zero rows means the model has no SDTM
variables.

## Details

A trace model records derivations as edges from a derived variable to
its source. An SDTM variable is used when at least one ADaM variable
maps to it, so this walks the same reverse adjacency as
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md):
it counts, for every SDTM variable, how many derivations point at it.
ADaM-to-SDTM mappings are the only edges that reach an SDTM node, so
`adam_derivations` never adds SDTM references; it is accepted for parity
with the rest of the engine and passed through unchanged. This is a pure
diagnostic and does not affect trace levels, coverage, or any scoring.

## See also

[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
for the forward question (what a source feeds), and
[`trace_problems()`](https://r4sub.github.io/r4subtrace/reference/trace_problems.md)
for ADaM-side traceability issues.

## Examples

``` r
adam <- data.frame(
  dataset = "ADSL", variable = "AGE", label = "Age"
)
sdtm <- data.frame(
  dataset = "DM", variable = c("AGE", "SEX"),
  label = c("Age", "Sex")
)
map <- data.frame(
  adam_dataset = "ADSL", adam_var = "AGE",
  sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
)
tm <- build_trace_model(adam, sdtm, mapping = map)
# DM.SEX is never referenced by an ADaM variable.
sdtm_utilization(tm)
#> # A tibble: 2 × 4
#>   dataset variable used_count referenced
#>   <chr>   <chr>         <int> <lgl>     
#> 1 DM      SEX               0 FALSE     
#> 2 DM      AGE               1 TRUE      

# With the bundled example metadata from r4subdata.
if (requireNamespace("r4subdata", quietly = TRUE)) {
  tm2 <- build_trace_model(
    r4subdata::adam_metadata,
    r4subdata::sdtm_metadata,
    mapping = r4subdata::trace_mapping
  )
  util <- sdtm_utilization(tm2)
  # Unused SDTM sources.
  util[!util$referenced, ]
}
#> # A tibble: 21 × 4
#>    dataset variable used_count referenced
#>    <chr>   <chr>         <int> <lgl>     
#>  1 AE      AEACN             0 FALSE     
#>  2 AE      AEENDTC           0 FALSE     
#>  3 AE      AEOUT             0 FALSE     
#>  4 AE      AEREL             0 FALSE     
#>  5 AE      AESTDTC           0 FALSE     
#>  6 AE      AETERM            0 FALSE     
#>  7 AE      DOMAIN            0 FALSE     
#>  8 DM      BRTHDTC           0 FALSE     
#>  9 DM      COUNTRY           0 FALSE     
#> 10 DM      DOMAIN            0 FALSE     
#> # ℹ 11 more rows
```
