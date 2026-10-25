# The Traceability Problems Worth Acting On

A full coverage table lists every variable; on a real submission with
tens of thousands of variables that is not what a team consumes. This
returns only the problems: variables that are not traced to the required
level, and, when `adam_derivations` is supplied, derivation chains that
never reach SDTM, that are circular, or that were cut off at the depth
limit. One variable can appear more than once when it has more than one
kind of problem.

## Usage

``` r
trace_problems(
  trace_model,
  traced_min_level = 2L,
  adam_derivations = NULL,
  trace_depth = 3L
)
```

## Arguments

- trace_model:

  A `trace_model` from
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md).

- traced_min_level:

  The minimum trace level that counts as traced, an integer in `0:3`.
  Default `2`.

- adam_derivations:

  Optional ADaM-to-ADaM derivation table (see
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)).
  When supplied, chain problems are included.

- trace_depth:

  Maximum chain depth to follow, passed to
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md).

## Value

A tibble with one row per problem: `adam_dataset`, `adam_var`, `problem`
(`"untraced"`, `"ungrounded"`, `"cycle"`, or `"truncated"`), and a
`detail` string. Empty when nothing is wrong.

## See also

[`traceability_coverage()`](https://r4sub.github.io/r4subtrace/reference/traceability_coverage.md)
for the full per-dataset rollup,
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
for the chains themselves.

## Examples

``` r
adam_meta <- data.frame(
  dataset = "ADSL", variable = c("USUBJID", "AGE", "DERIVED1"),
  label = c("Unique Subject ID", "Age", "Derived")
)
sdtm_meta <- data.frame(dataset = "DM", variable = c("USUBJID", "AGE"))
map <- data.frame(
  adam_dataset = "ADSL", adam_var = c("USUBJID", "AGE"),
  sdtm_domain = "DM", sdtm_var = c("USUBJID", "AGE"), confidence = c(1, 1)
)
tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
trace_problems(tm)
#> # A tibble: 1 × 4
#>   adam_dataset adam_var problem  detail                  
#>   <chr>        <chr>    <chr>    <chr>                   
#> 1 ADSL         DERIVED1 untraced trace level 1 is below 2
```
