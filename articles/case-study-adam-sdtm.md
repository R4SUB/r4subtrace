# Case study: tracing ADaM back to SDTM

Traceability is a filing requirement, but on most studies it lives as a
spreadsheet someone maintains by hand. `r4subtrace` treats it as data
instead: it takes your ADaM metadata, your SDTM metadata, and a mapping
sheet, builds a graph, and tells you exactly which variables can be
traced back to source and which cannot.

This case study uses the example CDISC pilot metadata that ships with
`r4subdata`.

``` r

library(r4subtrace)
library(r4subdata)
```

## The inputs

Three tables: what is in ADaM, what is in SDTM, and how the two connect.

``` r

head(adam_metadata, 3)
#> # A tibble: 3 × 6
#>   dataset variable label                     type  length format
#>   <chr>   <chr>    <chr>                     <chr>  <int> <chr> 
#> 1 ADSL    STUDYID  Study Identifier          Char      12 NA    
#> 2 ADSL    USUBJID  Unique Subject Identifier Char      20 NA    
#> 3 ADSL    SUBJID   Subject Identifier        Char       8 NA
head(sdtm_metadata, 3)
#> # A tibble: 3 × 6
#>   dataset variable label                     type  length format
#>   <chr>   <chr>    <chr>                     <chr>  <int> <chr> 
#> 1 DM      STUDYID  Study Identifier          Char      12 NA    
#> 2 DM      DOMAIN   Domain Abbreviation       Char       2 NA    
#> 3 DM      USUBJID  Unique Subject Identifier Char      20 NA
head(trace_mapping, 3)
#> # A tibble: 3 × 6
#>   adam_dataset adam_var sdtm_domain sdtm_var derivation_text          confidence
#>   <chr>        <chr>    <chr>       <chr>    <chr>                         <dbl>
#> 1 ADSL         STUDYID  DM          STUDYID  Direct copy from DM.STU…          1
#> 2 ADSL         USUBJID  DM          USUBJID  Direct copy from DM.USU…          1
#> 3 ADSL         SUBJID   DM          SUBJID   Direct copy from DM.SUB…          1
```

The mapping carries a derivation description and a confidence score for
each link, which is what lets the model tell a direct copy apart from a
documented derivation.

## Building the model

[`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md)
turns the three tables into nodes and edges, and flags the problems it
finds along the way.

``` r

tm <- build_trace_model(adam_metadata, sdtm_metadata, mapping = trace_mapping)
tm
#> ℹ Trace Model: 36 ADaM vars, 43 SDTM vars
#> ℹ   Edges: 25, Orphans: 11, Ambiguities: 0
```

The orphans in that summary are ADaM variables with no mapping row at
all. They are the first thing to chase, because an untraceable variable
is exactly what a reviewer will stop on.

``` r

tm$diagnostics$orphans
#> # A tibble: 11 × 2
#>    adam_dataset adam_var
#>    <chr>        <chr>   
#>  1 ADSL         TRT01P  
#>  2 ADSL         TRT01A  
#>  3 ADSL         SAFFL   
#>  4 ADSL         ITTFL   
#>  5 ADAE         AEREL   
#>  6 ADAE         AESTDTC 
#>  7 ADAE         AEENDTC 
#>  8 ADLB         PARAM   
#>  9 ADLB         AVISIT  
#> 10 ADLB         ABLFL   
#> 11 ADLB         ANL01FL
```

## Trace levels

[`compute_trace_levels()`](https://r4sub.github.io/r4subtrace/reference/compute_trace_levels.md)
assigns each ADaM variable a level from L0 (no mapping, no derivation)
up to L3 (mapped with high confidence or a documented derivation).

``` r

levels <- compute_trace_levels(tm)
table(levels$trace_level)
#> 
#>  1  3 
#> 11 25
```

That distribution is the honest coverage picture. Variables at L0 or L1
are the gap.

``` r

levels[levels$trace_level < 2, c("adam_dataset", "adam_var", "trace_level")]
#> # A tibble: 11 × 3
#>    adam_dataset adam_var trace_level
#>    <chr>        <chr>          <int>
#>  1 ADSL         TRT01P             1
#>  2 ADSL         TRT01A             1
#>  3 ADSL         SAFFL              1
#>  4 ADSL         ITTFL              1
#>  5 ADAE         AEREL              1
#>  6 ADAE         AESTDTC            1
#>  7 ADAE         AEENDTC            1
#>  8 ADLB         PARAM              1
#>  9 ADLB         AVISIT             1
#> 10 ADLB         ABLFL              1
#> 11 ADLB         ANL01FL            1
```

## Coverage as indicators

[`trace_model_to_evidence()`](https://r4sub.github.io/r4subtrace/reference/trace_model_to_evidence.md)
turns the model into R4SUB evidence, and
[`trace_indicator_scores()`](https://r4sub.github.io/r4subtrace/reference/trace_indicator_scores.md)
summarises it into the numbers that feed the Trace pillar of the
Submission Confidence Index.

``` r

ctx <- r4subcore::r4sub_run_context(study_id = "CDISCPILOT01", environment = "UAT")
#> ℹ Run context created: "R4S-20261025204255-wl4dieex"
ev  <- trace_model_to_evidence(tm, ctx = ctx)
#> ✔ Evidence table created: 47 rows
trace_indicator_scores(ev)
#> # A tibble: 5 × 3
#>   indicator                      value description                              
#>   <chr>                          <dbl> <chr>                                    
#> 1 TRACE_VAR_COVERAGE_L2PLUS      0.694 Proportion of ADaM variables with trace …
#> 2 TRACE_VAR_COVERAGE_L3PLUS      0.694 Proportion of ADaM variables with trace …
#> 3 TRACE_ORPHAN_VAR_COUNT        11     Number of orphan ADaM variables with no …
#> 4 TRACE_AMBIGUOUS_MAPPING_COUNT  0     Number of ADaM variables mapped to multi…
#> 5 TRACE_MEAN_TRACE_LEVEL         2.39  Mean trace level across all ADaM variabl…
```

Coverage, orphan count, ambiguous mappings, and mean trace level: those
are the signals the readiness score reads. Improving them is not a
documentation chore done at the end, it is a number the whole team can
watch move as the mapping gets completed.
