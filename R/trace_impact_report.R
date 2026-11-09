#' Summarize an Impact Analysis Result
#'
#' Rolls up the per-variable result of [trace_impact()] into the digest a data
#' team reads first: how many downstream variables are affected, broken down by
#' dataset and by distance (level) from the change. The detailed result from
#' [trace_impact()] lists every affected variable with its path; this condenses
#' it to counts, and prints a short overview as a side effect.
#'
#' @details
#' `summarize_impact()` does no graph work. It operates purely on the tibble
#' returned by [trace_impact()], reading the `"changed"` attribute to label the
#' change. "Level" here is the `depth` column: the number of derivation hops
#' between the changed variable and the affected one, so level 1 is a direct
#' dependent and deeper levels are reached through a chain.
#'
#' @param impact A tibble returned by [trace_impact()], with columns `dataset`,
#'   `variable`, `role`, `depth`, and `path`.
#' @param ... Ignored, for future extension.
#'
#' @return Invisibly, a list with two tibbles: `by_dataset` (one row per
#'   affected dataset with `n_impacted`, `nearest_depth`, `farthest_depth`) and
#'   `by_level` (one row per depth with `n_impacted`). A short summary is printed
#'   as a side effect. When nothing is impacted, both tibbles have zero rows.
#'
#' @examples
#' adam <- data.frame(
#'   dataset = c("ADSL", "ADAE", "ADTTE"), variable = c("AGE", "AAGE", "TAGE"),
#'   label = c("Age", "Analysis Age", "Time Age")
#' )
#' sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = "AGE",
#'   sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
#' )
#' tm <- build_trace_model(adam, sdtm, mapping = map)
#' deriv <- data.frame(
#'   from_dataset = c("ADAE", "ADTTE"), from_var = c("AAGE", "TAGE"),
#'   to_dataset = c("ADSL", "ADAE"), to_var = c("AGE", "AAGE")
#' )
#' imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv)
#' rollup <- summarize_impact(imp)
#' rollup$by_dataset
#'
#' @export
summarize_impact <- function(impact, ...) {
  validate_impact(impact)
  changed <- attr(impact, "changed")
  if (is.null(changed)) changed <- NA_character_

  if (nrow(impact) == 0L) {
    cli::cli_alert_info(
      "Impact of changing {.val {changed}}: no downstream variables affected."
    )
    return(invisible(list(
      by_dataset = tibble::tibble(
        dataset = character(0), n_impacted = integer(0),
        nearest_depth = integer(0), farthest_depth = integer(0)
      ),
      by_level = tibble::tibble(depth = integer(0), n_impacted = integer(0))
    )))
  }

  datasets <- sort(unique(impact$dataset))
  by_dataset <- dplyr::bind_rows(lapply(datasets, function(ds) {
    sub <- impact[impact$dataset == ds, , drop = FALSE]
    tibble::tibble(
      dataset        = ds,
      n_impacted     = nrow(sub),
      nearest_depth  = min(sub$depth),
      farthest_depth = max(sub$depth)
    )
  }))

  depths <- sort(unique(impact$depth))
  by_level <- dplyr::bind_rows(lapply(depths, function(d) {
    tibble::tibble(
      depth = as.integer(d),
      n_impacted = sum(impact$depth == d)
    )
  }))

  n <- nrow(impact)
  cli::cli_alert_info(
    "Impact of changing {.val {changed}}: {n} downstream variable{?s} affected."
  )
  ds_bits <- paste0(by_dataset$dataset, " (", by_dataset$n_impacted, ")")
  cli::cli_alert_info("  By dataset: {ds_bits}")
  lvl_bits <- paste0("L", by_level$depth, " (", by_level$n_impacted, ")")
  cli::cli_alert_info("  By level: {lvl_bits}")

  invisible(list(by_dataset = by_dataset, by_level = by_level))
}


#' Export an Impact Analysis Report
#'
#' Writes the result of [trace_impact()] as a report for a change-control
#' record: every affected downstream variable, its distance from the change, and
#' the derivation path back to it, with the changed variable recorded in a
#' leading column. The report can be returned as a data.frame or written to CSV
#' or Excel, mirroring [export_traceability_report()].
#'
#' @param impact A tibble returned by [trace_impact()], with columns `dataset`,
#'   `variable`, `role`, `depth`, and `path`.
#' @param format One of `"data.frame"`, `"csv"`, or `"xlsx"`.
#' @param path Output file path, required for `"csv"` and `"xlsx"`.
#'
#' @return For `"data.frame"`, the report tibble (a `changed` column followed by
#'   the impact detail). For `"csv"` and `"xlsx"`, the report is written to
#'   `path` and the path is returned invisibly.
#'
#' @examples
#' adam <- data.frame(
#'   dataset = c("ADSL", "ADAE"), variable = c("AGE", "AAGE"),
#'   label = c("Age", "Analysis Age")
#' )
#' sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = "AGE",
#'   sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
#' )
#' tm <- build_trace_model(adam, sdtm, mapping = map)
#' deriv <- data.frame(
#'   from_dataset = "ADAE", from_var = "AAGE",
#'   to_dataset = "ADSL", to_var = "AGE"
#' )
#' imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv)
#' export_impact_report(imp)
#'
#' @export
export_impact_report <- function(impact,
                                 format = c("data.frame", "csv", "xlsx"),
                                 path = NULL) {
  format <- match.arg(format)
  validate_impact(impact)

  changed <- attr(impact, "changed")
  if (is.null(changed)) changed <- NA_character_

  report <- tibble::tibble(
    changed  = rep(changed, nrow(impact)),
    dataset  = impact$dataset,
    variable = impact$variable,
    role     = impact$role,
    depth    = impact$depth,
    path     = impact$path
  )

  if (format == "data.frame") {
    return(report)
  }

  if (is.null(path) || !is.character(path) || length(path) != 1L) {
    cli::cli_abort("{.arg path} is required when {.arg format} is {.val {format}}.")
  }

  if (format == "csv") {
    utils::write.csv(report, path, row.names = FALSE)
  } else {
    if (!requireNamespace("writexl", quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg writexl} is required to write an Excel report."
      )
    }
    writexl::write_xlsx(report, path)
  }

  cli::cli_alert_success("Wrote impact report to {.file {path}}.")
  invisible(path)
}


# Confirm the object looks like a trace_impact() result.
validate_impact <- function(impact) {
  required <- c("dataset", "variable", "role", "depth", "path")
  if (!is.data.frame(impact) || !all(required %in% names(impact))) {
    cli::cli_abort(c(
      "{.arg impact} must be a result of {.fn trace_impact}.",
      "i" = "Expected a data frame with columns {.val {required}}."
    ))
  }
  invisible(impact)
}
