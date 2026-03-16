# Validate Dataset Metadata

Checks that an ADaM or SDTM metadata data.frame contains the required
columns (`dataset`, `variable`) and canonicalizes column names to
lowercase.

## Usage

``` r
validate_metadata(df, kind = c("adam", "sdtm"))
```

## Arguments

- df:

  A data.frame of dataset metadata.

- kind:

  Character; `"adam"` or `"sdtm"`. Used in error messages only.

## Value

A tibble with canonicalized column names.

## Examples

``` r
meta <- data.frame(DATASET = "ADSL", VARIABLE = "SUBJID", LABEL = "Subject ID")
validate_metadata(meta, kind = "adam")
#> # A tibble: 1 × 6
#>   dataset variable label      type  length format
#>   <chr>   <chr>    <chr>      <chr> <chr>  <chr> 
#> 1 ADSL    SUBJID   Subject ID NA    NA     NA    
```
