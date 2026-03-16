# Default Trace Configuration

Returns a list of default configuration values for trace model building
and evidence emission.

## Usage

``` r
trace_config_default(
  severity_by_level = c(L0 = "high", L1 = "medium", L2 = "low", L3 = "info"),
  result_by_level = c(L0 = "fail", L1 = "warn", L2 = "warn", L3 = "pass"),
  confidence_threshold_L3 = 0.8,
  uppercase_datasets = TRUE
)
```

## Arguments

- severity_by_level:

  Named character vector mapping trace levels to severity.

- result_by_level:

  Named character vector mapping trace levels to result.

- confidence_threshold_L3:

  Numeric threshold for L3 classification. A mapping must have
  confidence \>= this value to qualify for L3.

- uppercase_datasets:

  Logical; if `TRUE`, dataset and domain names are uppercased during
  canonicalization.

## Value

A list of class `"trace_config"` with elements: `severity_by_level`,
`result_by_level`, `confidence_threshold_L3`, `uppercase_datasets`.

## Examples

``` r
cfg <- trace_config_default()
cfg$severity_by_level
#>       L0       L1       L2       L3 
#>   "high" "medium"    "low"   "info" 

# Override a single setting
cfg2 <- trace_config_default(confidence_threshold_L3 = 0.9)
```
