# Follow Multi-Step Derivation Chains

Traces each ADaM variable back to its ultimate source through chains of
any depth, not just a single ADaM-to-SDTM hop. Real submissions often
derive an ADaM variable from another ADaM variable that is itself
derived from SDTM (for example an `ADAE` variable built from `ADSL`,
which in turn comes from `DM`). Shallow tracing misses those links and
understates coverage.

## Usage

``` r
trace_chains(trace_model, adam_derivations = NULL, trace_depth = 3L)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- adam_derivations:

  Optional data.frame of ADaM-to-ADaM derivations with columns
  `from_dataset`, `from_var`, `to_dataset`, `to_var`.

- trace_depth:

  Maximum number of hops to follow, a positive integer. Default `3`.

## Value

A tibble with one row per ADaM variable: `adam_dataset`, `adam_var`,
`max_depth` (longest chain in hops), `grounded` (a path reaches SDTM),
`terminal_source`, `has_cycle`, `truncated` (a path hit `trace_depth`),
`n_paths`, and `longest_chain` (a readable path string).

## Details

The ADaM-to-SDTM links come from the trace model's edges. ADaM-to-ADaM
links are supplied through `adam_derivations`, a data.frame with columns
`from_dataset`, `from_var`, `to_dataset`, `to_var`, where `from` is the
derived variable and `to` is its source. Each ADaM variable is walked
toward its sources until the path reaches an SDTM variable (grounded),
dead-ends at an ADaM variable with no further source (ungrounded),
revisits a node (a cycle), or reaches `trace_depth` hops.

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
trace_chains(tm, adam_derivations = deriv)
#> # A tibble: 2 × 9
#>   adam_dataset adam_var max_depth grounded terminal_source has_cycle truncated
#>   <chr>        <chr>        <int> <lgl>    <chr>           <lgl>     <lgl>    
#> 1 ADSL         AGE              1 TRUE     DM.AGE          FALSE     FALSE    
#> 2 ADAE         AAGE             2 TRUE     DM.AGE          FALSE     FALSE    
#> # ℹ 2 more variables: n_paths <int>, longest_chain <chr>
```
