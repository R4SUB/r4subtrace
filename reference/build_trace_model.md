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
#> 1 N-9abc20438c6cc0f617e83c62e34902db variable  ADSL    STUDYID  Study ID   adam 
#> 2 N-eb6b237955dda7f6d6398c61d4f92eea variable  ADSL    USUBJID  Unique Su… adam 
#> 3 N-61004a41aba4053d8a388d673f0af1ed variable  ADSL    AGE      Age        adam 
#> 4 N-ab72ae71f9c5cbafb45fe6f1b1381c35 variable  DM      STUDYID  Study ID   sdtm 
#> 5 N-ece07ff633f69358c033f22fe08096d0 variable  DM      USUBJID  Unique Su… sdtm 
#> 6 N-2da1b29c4b5973b2932a6594a818b684 variable  DM      AGE      Age        sdtm 
tm$edges
#> # A tibble: 3 × 5
#>   from_id                            to_id           edge_type confidence source
#>   <chr>                              <chr>           <chr>          <dbl> <chr> 
#> 1 N-9abc20438c6cc0f617e83c62e34902db N-ab72ae71f9c5… derived_…         NA mappi…
#> 2 N-eb6b237955dda7f6d6398c61d4f92eea N-ece07ff633f6… derived_…         NA mappi…
#> 3 N-61004a41aba4053d8a388d673f0af1ed N-2da1b29c4b59… derived_…         NA mappi…
```
