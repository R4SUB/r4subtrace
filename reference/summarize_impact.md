# Summarize an Impact Analysis Result

Rolls up the per-variable result of
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
into the digest a data team reads first: how many downstream variables
are affected, broken down by dataset and by distance (level) from the
change. The detailed result from
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
lists every affected variable with its path; this condenses it to
counts, and prints a short overview as a side effect.

## Usage

``` r
summarize_impact(impact, ...)
```

## Arguments

- impact:

  A tibble returned by
  [`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md),
  with columns `dataset`, `variable`, `role`, `depth`, and `path`.

- ...:

  Ignored, for future extension.

## Value

Invisibly, a list with two tibbles: `by_dataset` (one row per affected
dataset with `n_impacted`, `nearest_depth`, `farthest_depth`) and
`by_level` (one row per depth with `n_impacted`). A short summary is
printed as a side effect. When nothing is impacted, both tibbles have
zero rows.

## Details

`summarize_impact()` does no graph work. It operates purely on the
tibble returned by
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md),
reading the `"changed"` attribute to label the change. "Level" here is
the `depth` column: the number of derivation hops between the changed
variable and the affected one, so level 1 is a direct dependent and
deeper levels are reached through a chain.

## Examples

``` r
adam <- data.frame(
  dataset = c("ADSL", "ADAE", "ADTTE"), variable = c("AGE", "AAGE", "TAGE"),
  label = c("Age", "Analysis Age", "Time Age")
)
sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
map <- data.frame(
  adam_dataset = "ADSL", adam_var = "AGE",
  sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
)
tm <- build_trace_model(adam, sdtm, mapping = map)
deriv <- data.frame(
  from_dataset = c("ADAE", "ADTTE"), from_var = c("AAGE", "TAGE"),
  to_dataset = c("ADSL", "ADAE"), to_var = c("AGE", "AAGE")
)
imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv)
rollup <- summarize_impact(imp)
#> ℹ Impact of changing "DM.AGE": 3 downstream variables affected.
#> ℹ   By dataset: ADAE (1), ADSL (1), and ADTTE (1)
#> ℹ   By level: L1 (1), L2 (1), and L3 (1)
rollup$by_dataset
#> # A tibble: 3 × 4
#>   dataset n_impacted nearest_depth farthest_depth
#>   <chr>        <int>         <int>          <int>
#> 1 ADAE             1             2              2
#> 2 ADSL             1             1              1
#> 3 ADTTE            1             3              3
```
