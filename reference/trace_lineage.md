# Trace the Lineage of a Variable Through the Derivation Graph

Given a single variable, walks the derivation graph behind
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
and returns its lineage: either every upstream source it derives from
(its full ancestry) or every downstream variable that derives from it
(its dependents). This is the general path query over the graph;
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
is the special case of downstream dependents of a source variable.

## Usage

``` r
trace_lineage(
  trace_model,
  node,
  direction = c("upstream", "downstream"),
  adam_derivations = NULL,
  max_depth = Inf
)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- node:

  A single variable identifier as `"DATASET.VARIABLE"`, for example
  `"ADSL.AGE"`.

- direction:

  One of `"upstream"` (sources the node derives from, the default) or
  `"downstream"` (variables that derive from the node).

- adam_derivations:

  Optional data.frame of ADaM-to-ADaM derivations with columns
  `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).

- max_depth:

  Optional maximum number of hops to report. `Inf` (the default) reports
  the full transitive lineage.

## Value

A tibble with one row per related variable: `dataset`, `variable`,
`role`, `depth` (hops from the queried node), and `path` (a readable
derivation path reading outward from the node). Rows are ordered nearest
first. Zero rows means the node has no lineage in the requested
direction. The result carries `"node"` and `"direction"` attributes.

## Details

A directed edge runs from a derived variable to its source.
`trace_lineage()` follows those edges in one of two directions from the
queried node:

- `direction = "upstream"` follows edges forward, toward sources, and
  returns the transitive set of everything the variable is derived from,
  down to the SDTM variables that ground it.

- `direction = "downstream"` follows edges in reverse and returns the
  transitive set of variables that depend on it.

ADaM-to-ADaM derivations are included when supplied through
`adam_derivations`, exactly as in
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md),
so multi-step lineage is captured. Each related variable is reported
once, at its shortest distance from the queried node, with a readable
path that reads outward from the node. Circular references are handled
and do not loop.

## See also

[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
for downstream impact of a source variable,
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
for per-variable chain summaries,
[`validate_trace_graph()`](https://r4sub.github.io/r4subtrace/reference/validate_trace_graph.md)
for structural integrity checks.

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

# Where does ADAE.AAGE come from?
trace_lineage(tm, "ADAE.AAGE", "upstream", adam_derivations = deriv)
#> # A tibble: 2 × 5
#>   dataset variable role  depth path                           
#>   <chr>   <chr>    <chr> <int> <chr>                          
#> 1 ADSL    AGE      adam      1 ADAE.AAGE -> ADSL.AGE          
#> 2 DM      AGE      sdtm      2 ADAE.AAGE -> ADSL.AGE -> DM.AGE

# What depends on DM.AGE?
trace_lineage(tm, "DM.AGE", "downstream", adam_derivations = deriv)
#> # A tibble: 2 × 5
#>   dataset variable role  depth path                           
#>   <chr>   <chr>    <chr> <int> <chr>                          
#> 1 ADSL    AGE      adam      1 DM.AGE -> ADSL.AGE             
#> 2 ADAE    AAGE     adam      2 DM.AGE -> ADSL.AGE -> ADAE.AAGE
```
