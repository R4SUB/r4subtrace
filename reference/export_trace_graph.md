# Export the Derivation Graph to a Portable Text Format

Serializes the derivation graph behind
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
and
[`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
to a portable text format: Graphviz DOT, Mermaid, or GraphML. Unlike
[`plot_trace_graph()`](https://r4sub.github.io/r4subtrace/reference/plot_trace_graph.md),
which needs `igraph` and only renders interactively, this writes the
graph as text that can be committed to version control, embedded in an
ADRG or vignette, rendered by Graphviz, or opened in a graph editor such
as yEd.

## Usage

``` r
export_trace_graph(
  trace_model,
  format = c("dot", "mermaid", "graphml"),
  adam_derivations = NULL,
  file = NULL,
  include_isolated = TRUE
)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- format:

  One of `"dot"` (Graphviz), `"mermaid"`, or `"graphml"`.

- adam_derivations:

  Optional data.frame of ADaM-to-ADaM derivations with columns
  `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).

- file:

  Optional output file path. When supplied, the serialized graph is
  written there and the text is returned invisibly; otherwise the text
  is returned (a single string, one line per `\n`).

- include_isolated:

  Logical; when `TRUE` (the default) variable nodes with no derivation
  edge are included as isolated nodes. When `FALSE` only nodes that take
  part in at least one edge are emitted.

## Value

A length-one character string containing the serialized graph, returned
invisibly when `file` is supplied.

## Details

Nodes are ADaM and SDTM variables; a directed edge runs from a derived
variable to its source (`A -> B` reads "A is derived from B"), the same
direction used throughout the engine. ADaM-to-SDTM links come from the
trace model's mapping edges; ADaM-to-ADaM links are added when supplied
through `adam_derivations`, exactly as in
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).
Every variable node in the model is emitted, so orphan ADaM variables
(no outgoing edge) and unused SDTM sources (no incoming edge) appear as
isolated nodes unless `include_isolated = FALSE`. Node roles are
recorded so a renderer can colour ADaM and SDTM variables differently.
This is a pure serialization: it does not change trace levels, coverage,
or any scoring.

## See also

[`plot_trace_graph()`](https://r4sub.github.io/r4subtrace/reference/plot_trace_graph.md)
for interactive plotting with `igraph`,
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
deriv <- data.frame(
  from_dataset = "ADAE", from_var = "AAGE",
  to_dataset = "ADSL", to_var = "AGE"
)

# Graphviz DOT
cat(export_trace_graph(tm, "dot", adam_derivations = deriv))
#> digraph trace {
#>   rankdir=LR;
#>   node [fontname="Helvetica"];
#>   n1 [label="ADSL.AGE", fillcolor="#2C6DB5", style=filled, shape=box];
#>   n2 [label="ADAE.AAGE", fillcolor="#2C6DB5", style=filled, shape=box];
#>   n3 [label="DM.AGE", fillcolor="#F39C12", style=filled, shape=box];
#>   n1 -> n3;
#>   n2 -> n1;
#> }

# Mermaid, for a Markdown document
cat(export_trace_graph(tm, "mermaid", adam_derivations = deriv))
#> flowchart LR
#>   n1["ADSL.AGE"]
#>   n2["ADAE.AAGE"]
#>   n3["DM.AGE"]
#>   n1 --> n3
#>   n2 --> n1
#>   classDef adam fill:#2C6DB5,stroke:#1b4a7a,color:#ffffff;
#>   classDef sdtm fill:#F39C12,stroke:#9a6207,color:#ffffff;
#>   class n1,n2 adam;
#>   class n3 sdtm;
```
