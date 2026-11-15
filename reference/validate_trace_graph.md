# Validate the Structural Integrity of a Derivation Graph

Runs structural integrity checks over the derivation graph behind
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
and
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
and returns a tidy diagnostic report. These are purely structural graph
checks, not traceability scoring: they say whether the graph itself is
well formed before any coverage or level is read off it.

## Usage

``` r
validate_trace_graph(trace_model, adam_derivations = NULL)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- adam_derivations:

  Optional data.frame of ADaM-to-ADaM derivations with columns
  `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).

## Value

A tibble with one row per node per failing check: `check` (one of
`"cycle"`, `"dangling_edge"`, `"orphan"`, `"disconnected"`), `dataset`,
`variable`, `role`, and a readable `detail`. Zero rows means the graph
is structurally clean.

## Details

The graph is the same one the rest of the engine uses: nodes are ADaM
and SDTM variables and a directed edge runs from a derived variable to
its source (`A -> B` reads "A is derived from B"). ADaM-to-SDTM edges
come from the trace model's mapping; ADaM-to-ADaM edges are added when
supplied through `adam_derivations`, exactly as in
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).
Four checks are reported, one row per node per failing check:

- **`cycle`**: the node is part of a circular derivation chain (a
  variable that derives, directly or transitively, from itself). Found
  with a standard strongly-connected-component search, so every node in
  the cycle is flagged.

- **`dangling_edge`**: a derivation edge (always from
  `adam_derivations`) names this node as a source or dependent, but it
  is not present as a node in the trace model. The edge points at
  something that does not exist.

- **`orphan`**: the variable takes part in no derivation edge at all (an
  isolated node) - an ADaM variable mapped to nothing, or an SDTM
  variable read by nothing.

- **`disconnected`**: the node belongs to a connected component (two or
  more nodes joined by derivations) that contains no SDTM variable, so
  no path in that component can ever reach a source.

A node can appear in more than one check. Cycle detection, reachability,
and connected components are standard graph algorithms; nothing here
invents a domain weight, threshold, or score.

## See also

[`trace_lineage()`](https://r4sub.github.io/r4subtrace/reference/trace_lineage.md)
for ancestry and dependent queries,
[`trace_problems()`](https://r4sub.github.io/r4subtrace/reference/trace_problems.md)
for ADaM-side traceability issues,
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
for the graph model itself.

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

# A clean mapping reports nothing except the orphan ADAE.AAGE.
validate_trace_graph(tm)
#> # A tibble: 1 × 5
#>   check  dataset variable role  detail                                         
#>   <chr>  <chr>   <chr>    <chr> <chr>                                          
#> 1 orphan ADAE    AAGE     adam  isolated node: takes part in no derivation edge

# A circular derivation is detected.
cyc <- data.frame(
  from_dataset = c("ADSL", "ADAE"), from_var = c("AGE", "AAGE"),
  to_dataset   = c("ADAE", "ADSL"), to_var   = c("AAGE", "AGE")
)
validate_trace_graph(tm, adam_derivations = cyc)
#> # A tibble: 2 × 5
#>   check dataset variable role  detail                                           
#>   <chr> <chr>   <chr>    <chr> <chr>                                            
#> 1 cycle ADAE    AAGE     adam  part of a circular derivation chain among: ADAE.…
#> 2 cycle ADSL    AGE      adam  part of a circular derivation chain among: ADAE.…
```
