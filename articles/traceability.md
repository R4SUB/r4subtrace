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
#> 1 N-9abc20438c6cc0f617e83c62e34902db variable  ADSL    STUDYID  Study ID   adam 
#> 2 N-eb6b237955dda7f6d6398c61d4f92eea variable  ADSL    USUBJID  Unique Su… adam 
#> 3 N-61004a41aba4053d8a388d673f0af1ed variable  ADSL    AGE      Age        adam 
#> 4 N-05ff9c7794a452f7a2e571197bfc00b8 variable  ADSL    SEX      Sex        adam 
#> 5 N-921039f11a132416e1358dbbf77c47b1 variable  ADSL    TRT01P   Planned T… adam 
#> 6 N-ab72ae71f9c5cbafb45fe6f1b1381c35 variable  DM      STUDYID  Study ID   sdtm
head(tm$edges)
#> # A tibble: 5 × 5
#>   from_id                            to_id           edge_type confidence source
#>   <chr>                              <chr>           <chr>          <dbl> <chr> 
#> 1 N-9abc20438c6cc0f617e83c62e34902db N-ab72ae71f9c5… derived_…         NA mappi…
#> 2 N-eb6b237955dda7f6d6398c61d4f92eea N-ece07ff633f6… derived_…         NA mappi…
#> 3 N-61004a41aba4053d8a388d673f0af1ed N-2da1b29c4b59… derived_…         NA mappi…
#> 4 N-05ff9c7794a452f7a2e571197bfc00b8 N-41c3ec10e8af… derived_…         NA mappi…
#> 5 N-921039f11a132416e1358dbbf77c47b1 N-748b4078dc56… derived_…         NA mappi…
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

## Coverage report for the ADRG

Once a trace model is built,
[`export_traceability_report()`](https://r4sub.github.io/r4subtrace/reference/export_traceability_report.md)
produces the coverage table an ADRG appendix needs: how much of each
ADaM dataset traces back to SDTM, which variables do not, and an overall
summary row.

``` r

report <- export_traceability_report(tm)
report
#> # A tibble: 2 × 6
#>   adam_dataset n_variables n_traced n_untraced pct_traced untraced_vars
#>   <chr>              <int>    <int>      <int>      <dbl> <chr>        
#> 1 ADSL                   5        5          0        100 ""           
#> 2 OVERALL                5        5          0        100 ""
```

A variable counts as traced when its trace level reaches
`traced_min_level` (the default of 2 treats an existing SDTM mapping as
traced). Raise it to 3 to require a high-confidence mapping. Pass
`format = "csv"` or `format = "xlsx"` with a `path` to write the table
straight into a submission package:

``` r

export_traceability_report(tm, format = "csv", path = "traceability.csv")
```

## Multi-step derivation chains

A direct ADaM-to-SDTM mapping is only the simplest case. Many variables
are derived from other ADaM variables that are themselves derived from
SDTM. A single hop misses those links.
[`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
follows the full path back to source, using an `adam_derivations` table
for the ADaM-to-ADaM steps.

``` r

adam <- data.frame(
  dataset  = c("ADSL", "ADAE", "ADTTE"),
  variable = c("AGE", "AAGE", "TAGE"),
  label    = c("Age", "Analysis Age", "Time-to-event Age")
)
sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
map  <- data.frame(
  adam_dataset = "ADSL", adam_var = "AGE",
  sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
)
tmc <- build_trace_model(adam, sdtm, mapping = map)

deriv <- data.frame(
  from_dataset = c("ADAE", "ADTTE"),
  from_var     = c("AAGE", "TAGE"),
  to_dataset   = c("ADSL", "ADAE"),
  to_var       = c("AGE", "AAGE")
)

trace_chains(tmc, adam_derivations = deriv)
#> # A tibble: 3 × 9
#>   adam_dataset adam_var max_depth grounded terminal_source has_cycle truncated
#>   <chr>        <chr>        <int> <lgl>    <chr>           <lgl>     <lgl>    
#> 1 ADSL         AGE              1 TRUE     DM.AGE          FALSE     FALSE    
#> 2 ADAE         AAGE             2 TRUE     DM.AGE          FALSE     FALSE    
#> 3 ADTTE        TAGE             3 TRUE     DM.AGE          FALSE     FALSE    
#> # ℹ 2 more variables: n_paths <int>, longest_chain <chr>
```

`ADTTE.TAGE` is three hops from source, but it is fully grounded: the
chain reaches `DM.AGE`. The `trace_depth` argument caps how far the walk
follows a chain, and circular derivations are detected and reported
rather than looping forever.

## Focusing on the problems

A coverage table lists every variable. On a real submission with
thousands of variables, a team wants only the ones that need attention.
[`trace_problems()`](https://r4sub.github.io/r4subtrace/reference/trace_problems.md)
returns just those: variables not traced to the required level, and,
when a derivation table is given, chains that are circular, cut off, or
never reach SDTM.

``` r

trace_problems(tm2)
#> # A tibble: 1 × 4
#>   adam_dataset adam_var    problem  detail                  
#>   <chr>        <chr>       <chr>    <chr>                   
#> 1 ADSL         DERIVED_VAR untraced trace level 1 is below 2
```

Passing the derivation table adds chain problems to the same view, so
cycles and ungrounded derivations show up alongside untraced variables:

``` r

trace_problems(tmc, adam_derivations = deriv)
#> # A tibble: 2 × 4
#>   adam_dataset adam_var problem  detail                  
#>   <chr>        <chr>    <chr>    <chr>                   
#> 1 ADAE         AAGE     untraced trace level 1 is below 2
#> 2 ADTTE        TAGE     untraced trace level 1 is below 2
```

The view is built from the same coverage and chain functions, so it
stays correct as a submission grows; the engine is exercised on a
10,000-variable model in the package tests.
