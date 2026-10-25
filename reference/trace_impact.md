# Impact Analysis for a Changed Source Variable

Answers the question a data team asks before touching a source variable:
if this changes, what downstream ADaM variables are affected? Given a
trace model and a variable that is about to change, `trace_impact()`
follows the derivation graph in reverse and returns every variable that
derives from it, directly or through a chain.

## Usage

``` r
trace_impact(trace_model, changed, adam_derivations = NULL, max_depth = Inf)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- changed:

  A single variable identifier as `"DATASET.VARIABLE"`, for example
  `"DM.AGE"` or `"ADSL.AGE"`.

- adam_derivations:

  Optional data.frame of ADaM-to-ADaM derivations with columns
  `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).

- max_depth:

  Optional maximum number of hops to report. `Inf` (the default) reports
  the full transitive set.

## Value

A tibble with one row per impacted variable: `dataset`, `variable`,
`role`, `depth` (hops from the change), and `path` (a readable
derivation path from the impacted variable back to the changed one).
Rows are ordered nearest first. Zero rows means nothing derives from the
variable. The result carries a `"changed"` attribute with the resolved
identifier.

## Details

The trace model records derivations as edges from a derived variable to
its source. Impact analysis walks those edges backwards from the changed
variable to find its dependents. ADaM-to-ADaM derivations are included
when supplied through `adam_derivations`, exactly as in
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md),
so multi-step impact (an `ADTTE` variable built from an `ADSL` variable
built from `DM`) is captured. Each dependent is reported once, at its
shortest distance from the change, with a readable path back to it.
Circular references are handled and do not loop.

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
# If DM.AGE changes, what is affected?
trace_impact(tm, "DM.AGE", adam_derivations = deriv)
#> # A tibble: 2 × 5
#>   dataset variable role  depth path                           
#>   <chr>   <chr>    <chr> <int> <chr>                          
#> 1 ADSL    AGE      adam      1 ADSL.AGE -> DM.AGE             
#> 2 ADAE    AAGE     adam      2 ADAE.AAGE -> ADSL.AGE -> DM.AGE
```
