#' The Traceability Problems Worth Acting On
#'
#' A full coverage table lists every variable; on a real submission with tens of
#' thousands of variables that is not what a team consumes. This returns only the
#' problems: variables that are not traced to the required level, and, when
#' `adam_derivations` is supplied, derivation chains that never reach SDTM, that
#' are circular, or that were cut off at the depth limit. One variable can appear
#' more than once when it has more than one kind of problem.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param traced_min_level The minimum trace level that counts as traced, an
#'   integer in `0:3`. Default `2`.
#' @param adam_derivations Optional ADaM-to-ADaM derivation table (see
#'   [trace_chains()]). When supplied, chain problems are included.
#' @param trace_depth Maximum chain depth to follow, passed to [trace_chains()].
#'
#' @return A tibble with one row per problem: `adam_dataset`, `adam_var`,
#'   `problem` (`"untraced"`, `"ungrounded"`, `"cycle"`, or `"truncated"`), and a
#'   `detail` string. Empty when nothing is wrong.
#'
#' @seealso [traceability_coverage()] for the full per-dataset rollup,
#'   [trace_chains()] for the chains themselves.
#'
#' @examples
#' adam_meta <- data.frame(
#'   dataset = "ADSL", variable = c("USUBJID", "AGE", "DERIVED1"),
#'   label = c("Unique Subject ID", "Age", "Derived")
#' )
#' sdtm_meta <- data.frame(dataset = "DM", variable = c("USUBJID", "AGE"))
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = c("USUBJID", "AGE"),
#'   sdtm_domain = "DM", sdtm_var = c("USUBJID", "AGE"), confidence = c(1, 1)
#' )
#' tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
#' trace_problems(tm)
#'
#' @export
trace_problems <- function(trace_model, traced_min_level = 2L,
                           adam_derivations = NULL, trace_depth = 3L) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }

  empty <- tibble::tibble(
    adam_dataset = character(0), adam_var = character(0),
    problem = character(0), detail = character(0)
  )

  levels <- compute_trace_levels(trace_model)
  parts <- list()

  if (nrow(levels) > 0L) {
    untraced <- levels[levels$trace_level < traced_min_level, , drop = FALSE]
    if (nrow(untraced) > 0L) {
      parts[[length(parts) + 1L]] <- tibble::tibble(
        adam_dataset = untraced$adam_dataset,
        adam_var     = untraced$adam_var,
        problem      = "untraced",
        detail       = sprintf("trace level %d is below %d",
                               untraced$trace_level, traced_min_level)
      )
    }
  }

  if (!is.null(adam_derivations)) {
    chains <- trace_chains(trace_model, adam_derivations = adam_derivations,
                           trace_depth = trace_depth)
    if (nrow(chains) > 0L) {
      cyc <- chains[chains$has_cycle, , drop = FALSE]
      if (nrow(cyc) > 0L) {
        parts[[length(parts) + 1L]] <- tibble::tibble(
          adam_dataset = cyc$adam_dataset, adam_var = cyc$adam_var,
          problem = "cycle", detail = "derivation chain is circular"
        )
      }
      trunc <- chains[chains$truncated & !chains$has_cycle, , drop = FALSE]
      if (nrow(trunc) > 0L) {
        parts[[length(parts) + 1L]] <- tibble::tibble(
          adam_dataset = trunc$adam_dataset, adam_var = trunc$adam_var,
          problem = "truncated",
          detail = sprintf("chain exceeds the depth limit of %d", trace_depth)
        )
      }
      ungr <- chains[!chains$grounded & !chains$has_cycle & !chains$truncated,
                     , drop = FALSE]
      if (nrow(ungr) > 0L) {
        parts[[length(parts) + 1L]] <- tibble::tibble(
          adam_dataset = ungr$adam_dataset, adam_var = ungr$adam_var,
          problem = "ungrounded",
          detail = "derivation chain does not reach an SDTM source"
        )
      }
    }
  }

  if (length(parts) == 0L) {
    return(empty)
  }
  out <- dplyr::bind_rows(parts)
  out[order(out$adam_dataset, out$adam_var, out$problem), , drop = FALSE]
}
