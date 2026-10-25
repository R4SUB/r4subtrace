# Plot a Derivation Graph

Draws the derivation graph behind
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
using `igraph`: ADaM and SDTM variables as nodes, derivation links as
directed edges.

## Usage

``` r
plot_trace_graph(trace_model, adam_derivations = NULL, ...)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- adam_derivations:

  Optional ADaM-to-ADaM derivations, as in
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).

- ...:

  Passed to
  [`igraph::plot.igraph()`](https://r.igraph.org/reference/plot.igraph.html).

## Value

The `igraph` object, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
plot_trace_graph(tm, adam_derivations = deriv)
} # }
```
