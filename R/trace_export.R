#' Traceability Coverage by ADaM Dataset
#'
#' Summarizes how much of each ADaM dataset is traced back to SDTM. A variable
#' counts as traced when its trace level reaches `traced_min_level`. The default
#' of `2` treats an existing SDTM mapping (level L2) as traced.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param traced_min_level The minimum trace level that counts as traced, an
#'   integer in `0:3`. Default `2`.
#'
#' @return A tibble with one row per ADaM dataset: `adam_dataset`,
#'   `n_variables`, `n_traced`, `n_untraced`, `pct_traced`, and `untraced_vars`
#'   (a comma-separated list, empty when the dataset is fully traced).
#'
#' @examples
#' adam_meta <- data.frame(
#'   dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGEGR1"),
#'   label = c("Study ID", "Unique Subject ID", NA)
#' )
#' sdtm_meta <- data.frame(dataset = "DM", variable = c("STUDYID", "USUBJID"))
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID"),
#'   sdtm_domain = "DM", sdtm_var = c("STUDYID", "USUBJID"),
#'   confidence = c(1, 1)
#' )
#' tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
#' traceability_coverage(tm)
#'
#' @export
traceability_coverage <- function(trace_model, traced_min_level = 2L) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }
  if (!is.numeric(traced_min_level) || length(traced_min_level) != 1L ||
      traced_min_level < 0 || traced_min_level > 3) {
    cli::cli_abort("{.arg traced_min_level} must be a single integer in 0:3.")
  }

  levels <- compute_trace_levels(trace_model)

  if (nrow(levels) == 0L) {
    return(tibble::tibble(
      adam_dataset = character(0), n_variables = integer(0),
      n_traced = integer(0), n_untraced = integer(0),
      pct_traced = numeric(0), untraced_vars = character(0)
    ))
  }

  levels$traced <- levels$trace_level >= traced_min_level
  datasets <- sort(unique(levels$adam_dataset))

  rows <- lapply(datasets, function(ds) {
    sub <- levels[levels$adam_dataset == ds, , drop = FALSE]
    n <- nrow(sub)
    n_traced <- sum(sub$traced)
    untraced <- sub$adam_var[!sub$traced]

    tibble::tibble(
      adam_dataset  = ds,
      n_variables   = as.integer(n),
      n_traced      = as.integer(n_traced),
      n_untraced    = as.integer(n - n_traced),
      pct_traced    = round(n_traced / n * 100, 1),
      untraced_vars = paste(untraced, collapse = ", ")
    )
  })

  dplyr::bind_rows(rows)
}


#' Export a Traceability Coverage Report
#'
#' Produces the coverage table an ADRG appendix needs: per-dataset traceability
#' percentages, the untraced variables, and an overall summary row. The report
#' can be returned as a data.frame or written to CSV or Excel for inclusion in a
#' submission package.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param format One of `"data.frame"`, `"csv"`, or `"xlsx"`.
#' @param path Output file path, required for `"csv"` and `"xlsx"`.
#' @param traced_min_level The minimum trace level that counts as traced.
#'   Passed to [traceability_coverage()].
#'
#' @return For `"data.frame"`, the report tibble. For `"csv"` and `"xlsx"`, the
#'   report is written to `path` and the path is returned invisibly.
#'
#' @examples
#' adam_meta <- data.frame(
#'   dataset = "ADSL", variable = c("STUDYID", "AGEGR1"),
#'   label = c("Study ID", NA)
#' )
#' sdtm_meta <- data.frame(dataset = "DM", variable = "STUDYID")
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = "STUDYID",
#'   sdtm_domain = "DM", sdtm_var = "STUDYID", confidence = 1
#' )
#' tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
#' export_traceability_report(tm)
#'
#' @export
export_traceability_report <- function(trace_model,
                                       format = c("data.frame", "csv", "xlsx"),
                                       path = NULL,
                                       traced_min_level = 2L) {
  format <- match.arg(format)
  coverage <- traceability_coverage(trace_model, traced_min_level)

  report <- add_overall_row(coverage)

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

  cli::cli_alert_success("Wrote traceability report to {.file {path}}.")
  invisible(path)
}


# Append an overall summary row that totals every dataset.
add_overall_row <- function(coverage) {
  if (nrow(coverage) == 0L) {
    return(tibble::tibble(
      adam_dataset = "OVERALL", n_variables = 0L, n_traced = 0L,
      n_untraced = 0L, pct_traced = NA_real_, untraced_vars = ""
    ))
  }

  n <- sum(coverage$n_variables)
  n_traced <- sum(coverage$n_traced)

  overall <- tibble::tibble(
    adam_dataset  = "OVERALL",
    n_variables   = as.integer(n),
    n_traced      = as.integer(n_traced),
    n_untraced    = as.integer(n - n_traced),
    pct_traced    = if (n > 0) round(n_traced / n * 100, 1) else NA_real_,
    untraced_vars = ""
  )

  dplyr::bind_rows(coverage, overall)
}
