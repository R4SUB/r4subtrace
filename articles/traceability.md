# Traceability Analysis with r4subtrace

Traceability is a core regulatory requirement: reviewers must be able to
follow every analysis variable from its source SDTM domain through any
derivation to the final ADaM dataset. The `r4subtrace` package builds a
directed trace model and evaluates coverage.

``` r
library(r4subtrace)
```

## Default configuration

``` r
cfg <- trace_config_default()
str(cfg)
#> List of 4
#>  $ severity_by_level      : Named chr [1:4] "high" "medium" "low" "info"
#>   ..- attr(*, "names")= chr [1:4] "L0" "L1" "L2" "L3"
#>  $ result_by_level        : Named chr [1:4] "fail" "warn" "warn" "pass"
#>   ..- attr(*, "names")= chr [1:4] "L0" "L1" "L2" "L3"
#>  $ confidence_threshold_L3: num 0.8
#>  $ uppercase_datasets     : logi TRUE
#>  - attr(*, "class")= chr "trace_config"
```

## Building a trace model

[`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md)
takes ADaM metadata, SDTM metadata, and an optional mapping sheet. It
returns a `trace_model` object with nodes, edges, and diagnostic
information.

``` r
adam_meta <- data.frame(
  dataset  = rep("ADSL", 5),
  variable = c("STUDYID", "USUBJID", "AGE", "SEX", "TRT01P"),
  label    = c("Study ID", "Unique Subject ID", "Age",
               "Sex", "Planned Treatment"),
  stringsAsFactors = FALSE
)

sdtm_meta <- data.frame(
  dataset  = c(rep("DM", 4), "EX"),
  variable = c("STUDYID", "USUBJID", "AGE", "SEX", "EXTRT"),
  label    = c("Study ID", "Unique Subject ID", "Age",
               "Sex", "Treatment Name"),
  stringsAsFactors = FALSE
)

mapping <- data.frame(
  adam_dataset = rep("ADSL", 5),
  adam_var     = c("STUDYID", "USUBJID", "AGE", "SEX", "TRT01P"),
  sdtm_domain  = c("DM", "DM", "DM", "DM", "EX"),
  sdtm_var     = c("STUDYID", "USUBJID", "AGE", "SEX", "EXTRT"),
  stringsAsFactors = FALSE
)

tm <- build_trace_model(adam_meta, sdtm_meta, mapping = mapping)
print(tm)
#> ℹ Trace Model: 5 ADaM vars, 5 SDTM vars
#> ℹ   Edges: 5, Orphans: 0, Ambiguities: 0
```

## Inspecting the trace model

The `nodes` tibble lists all assets; `edges` describes the
relationships:

``` r
head(tm$nodes)
#> # A tibble: 6 × 6
#>   node_id                            node_type dataset variable label      role 
#>   <chr>                              <chr>     <chr>   <chr>    <chr>      <chr>
#> 1 N-b1ac6405e4b59cfc8dee303e0360acd0 variable  ADSL    STUDYID  Study ID   adam 
#> 2 N-59a38e629aca6bc554054c09d218b214 variable  ADSL    USUBJID  Unique Su… adam 
#> 3 N-05e02c840082204d934e8bf0af3d7116 variable  ADSL    AGE      Age        adam 
#> 4 N-f48867c9e22f0a29a60b6adc0fc0c7c1 variable  ADSL    SEX      Sex        adam 
#> 5 N-c213d93842abc942cabfc42e44d3f027 variable  ADSL    TRT01P   Planned T… adam 
#> 6 N-cc0edb9be98d14ec9467d7b85ed1daa3 variable  DM      STUDYID  Study ID   sdtm
head(tm$edges)
#> # A tibble: 5 × 5
#>   from_id                            to_id           edge_type confidence source
#>   <chr>                              <chr>           <chr>          <dbl> <chr> 
#> 1 N-b1ac6405e4b59cfc8dee303e0360acd0 N-cc0edb9be98d… derived_…         NA mappi…
#> 2 N-59a38e629aca6bc554054c09d218b214 N-37ed8581c0a7… derived_…         NA mappi…
#> 3 N-05e02c840082204d934e8bf0af3d7116 N-c627fc67fb46… derived_…         NA mappi…
#> 4 N-f48867c9e22f0a29a60b6adc0fc0c7c1 N-b83e6aca42cb… derived_…         NA mappi…
#> 5 N-c213d93842abc942cabfc42e44d3f027 N-7b80b9efed5b… derived_…         NA mappi…
```

Diagnostic information flags any orphan variables (unmapped ADaM
variables):

``` r
tm$diagnostics$orphans
#> # A tibble: 0 × 2
#> # ℹ 2 variables: adam_dataset <chr>, adam_var <chr>
```

## Computing trace levels

[`compute_trace_levels()`](https://r4sub.github.io/r4subtrace/reference/compute_trace_levels.md)
summarises coverage per ADaM dataset:

``` r
tl <- compute_trace_levels(tm)
tl
#> # A tibble: 5 × 7
#>   adam_dataset adam_var trace_level has_mapping has_derivation_text n_candidates
#>   <chr>        <chr>          <int> <lgl>       <lgl>                      <int>
#> 1 ADSL         STUDYID            3 TRUE        TRUE                           1
#> 2 ADSL         USUBJID            3 TRUE        TRUE                           1
#> 3 ADSL         AGE                3 TRUE        TRUE                           1
#> 4 ADSL         SEX                3 TRUE        TRUE                           1
#> 5 ADSL         TRT01P             3 TRUE        TRUE                           1
#> # ℹ 1 more variable: max_confidence <dbl>
```

## Indicator scores from evidence

If you have an evidence table with `indicator_domain == "trace"`,
[`trace_indicator_scores()`](https://r4sub.github.io/r4subtrace/reference/trace_indicator_scores.md)
computes per-indicator aggregates:

``` r
ev_trace <- data.frame(
  indicator_id     = c("T-001", "T-001", "T-002"),
  indicator_domain = "trace",
  result           = c("pass", "warn", "fail"),
  metric_value     = c(1.0, 0.8, 0.0),
  metric_unit      = "proportion",
  severity         = c("info", "medium", "high"),
  stringsAsFactors = FALSE
)

trace_indicator_scores(ev_trace)
#> # A tibble: 5 × 3
#>   indicator                     value description                               
#>   <chr>                         <dbl> <chr>                                     
#> 1 TRACE_VAR_COVERAGE_L2PLUS        NA Proportion of ADaM variables with trace l…
#> 2 TRACE_VAR_COVERAGE_L3PLUS        NA Proportion of ADaM variables with trace l…
#> 3 TRACE_ORPHAN_VAR_COUNT            0 Number of orphan ADaM variables with no S…
#> 4 TRACE_AMBIGUOUS_MAPPING_COUNT     0 Number of ADaM variables mapped to multip…
#> 5 TRACE_MEAN_TRACE_LEVEL           NA Mean trace level across all ADaM variables
```

## Partial mapping (orphans)

When a variable has no mapping entry, it appears as an orphan:

``` r
adam_partial <- data.frame(
  dataset  = rep("ADSL", 3),
  variable = c("USUBJID", "AGE", "DERIVED_VAR"),
  label    = c("Unique Subject ID", "Age", "Derived Variable"),
  stringsAsFactors = FALSE
)
mapping_partial <- data.frame(
  adam_dataset = c("ADSL", "ADSL"),
  adam_var     = c("USUBJID", "AGE"),
  sdtm_domain  = c("DM", "DM"),
  sdtm_var     = c("USUBJID", "AGE"),
  stringsAsFactors = FALSE
)
tm2 <- build_trace_model(adam_partial, sdtm_meta, mapping = mapping_partial)
tm2$diagnostics$orphans
#> # A tibble: 1 × 2
#>   adam_dataset adam_var   
#>   <chr>        <chr>      
#> 1 ADSL         DERIVED_VAR
```

Orphaned variables (like `DERIVED_VAR` above) should have derivation
text documented to satisfy U-002 and T-002 requirements.
