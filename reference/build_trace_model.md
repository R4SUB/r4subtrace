# Build a Trace Model

Constructs a directed trace model (nodes + edges + diagnostics) from
ADaM metadata, SDTM metadata, and an optional mapping sheet.

## Usage

``` r
build_trace_model(
  adam_meta,
  sdtm_meta,
  mapping = NULL,
  spec = NULL,
  config = trace_config_default()
)
```

## Arguments

- adam_meta:

  A data.frame of ADaM variable metadata. Must contain `dataset` and
  `variable` columns.

- sdtm_meta:

  A data.frame of SDTM variable metadata. Must contain `dataset` and
  `variable` columns.

- mapping:

  An optional data.frame describing ADaM-to-SDTM mappings. Must contain
  `adam_dataset`, `adam_var`, `sdtm_domain`, `sdtm_var`.

- spec:

  Reserved for future use (ADaM spec ingestion).

- config:

  A `trace_config` object from
  [`trace_config_default()`](https://r4sub.github.io/r4subtrace/reference/trace_config_default.md).

## Value

A list of class `"trace_model"` with elements:

- `nodes`: tibble of asset nodes (datasets and variables)

- `edges`: tibble of relationships between nodes

- `diagnostics`: list of tibbles (`orphans`, `ambiguities`, `conflicts`)

- `config`: the configuration used

## Examples

``` r
adam_meta <- data.frame(
  dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGE"),
  label = c("Study ID", "Unique Subject ID", "Age")
)
sdtm_meta <- data.frame(
  dataset = "DM", variable = c("STUDYID", "USUBJID", "AGE"),
  label = c("Study ID", "Unique Subject ID", "Age")
)
map <- data.frame(
  adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID", "AGE"),
  sdtm_domain = "DM",   sdtm_var = c("STUDYID", "USUBJID", "AGE")
)
tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
tm$nodes
#> # A tibble: 6 × 6
#>   node_id                            node_type dataset variable label      role 
#>   <chr>                              <chr>     <chr>   <chr>    <chr>      <chr>
#> 1 N-b1ac6405e4b59cfc8dee303e0360acd0 variable  ADSL    STUDYID  Study ID   adam 
#> 2 N-59a38e629aca6bc554054c09d218b214 variable  ADSL    USUBJID  Unique Su… adam 
#> 3 N-05e02c840082204d934e8bf0af3d7116 variable  ADSL    AGE      Age        adam 
#> 4 N-cc0edb9be98d14ec9467d7b85ed1daa3 variable  DM      STUDYID  Study ID   sdtm 
#> 5 N-37ed8581c0a7f820a06c6587d071588b variable  DM      USUBJID  Unique Su… sdtm 
#> 6 N-c627fc67fb46e908198f7a5c9865f806 variable  DM      AGE      Age        sdtm 
tm$edges
#> # A tibble: 3 × 5
#>   from_id                            to_id           edge_type confidence source
#>   <chr>                              <chr>           <chr>          <dbl> <chr> 
#> 1 N-b1ac6405e4b59cfc8dee303e0360acd0 N-cc0edb9be98d… derived_…         NA mappi…
#> 2 N-59a38e629aca6bc554054c09d218b214 N-37ed8581c0a7… derived_…         NA mappi…
#> 3 N-05e02c840082204d934e8bf0af3d7116 N-c627fc67fb46… derived_…         NA mappi…
```
