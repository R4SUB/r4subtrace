# Validate Trace Mapping

Checks that a mapping data.frame contains the required columns
(`adam_dataset`, `adam_var`, `sdtm_domain`, `sdtm_var`) and
canonicalizes names, trims whitespace, and optionally uppercases
dataset/domain names.

## Usage

``` r
validate_mapping(df, uppercase_datasets = TRUE)
```

## Arguments

- df:

  A data.frame describing ADaM-to-SDTM variable mappings.

- uppercase_datasets:

  Logical; if `TRUE`, uppercases `adam_dataset` and `sdtm_domain`.
  Default `TRUE`.

## Value

A tibble with canonicalized column names and values.

## Examples

``` r
map <- data.frame(
  ADAM_DATASET = "adsl", ADAM_VAR = "AGE",
  SDTM_DOMAIN = "dm", SDTM_VAR = "AGE"
)
validate_mapping(map)
#> # A tibble: 1 × 6
#>   adam_dataset adam_var sdtm_domain sdtm_var derivation_text confidence
#>   <chr>        <chr>    <chr>       <chr>    <chr>                <dbl>
#> 1 ADSL         AGE      DM          AGE      NA                      NA
```
