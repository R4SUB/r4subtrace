#' Default Trace Configuration
#'
#' Returns a list of default configuration values for trace model building
#' and evidence emission.
#'
#' @param severity_by_level Named character vector mapping trace levels to severity.
#' @param result_by_level Named character vector mapping trace levels to result.
#' @param confidence_threshold_L3 Numeric threshold for L3 classification.
#'   A mapping must have confidence >= this value to qualify for L3.
#' @param uppercase_datasets Logical; if `TRUE`, dataset and domain names are
#'   uppercased during canonicalization.
#'
#' @return A list of class `"trace_config"` with elements:
#'   `severity_by_level`, `result_by_level`, `confidence_threshold_L3`,
#'   `uppercase_datasets`.
#'
#' @examples
#' cfg <- trace_config_default()
#' cfg$severity_by_level
#'
#' # Override a single setting
#' cfg2 <- trace_config_default(confidence_threshold_L3 = 0.9)
#'
#' @export
trace_config_default <- function(
    severity_by_level = c(L0 = "high", L1 = "medium", L2 = "low", L3 = "info"),
    result_by_level   = c(L0 = "fail", L1 = "warn", L2 = "warn", L3 = "pass"),
    confidence_threshold_L3 = 0.8,
    uppercase_datasets = TRUE
) {
  stopifnot(
    is.numeric(confidence_threshold_L3),
    length(confidence_threshold_L3) == 1L,
    is.logical(uppercase_datasets),
    length(uppercase_datasets) == 1L
  )

  structure(
    list(
      severity_by_level       = severity_by_level,
      result_by_level         = result_by_level,
      confidence_threshold_L3 = confidence_threshold_L3,
      uppercase_datasets      = uppercase_datasets
    ),
    class = "trace_config"
  )
}
