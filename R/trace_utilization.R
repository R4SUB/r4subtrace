#' Report Unused SDTM Source Variables
#'
#' The mirror image of orphan detection. Orphans are ADaM variables that trace
#' to nothing; `sdtm_utilization()` asks the opposite question of the sources:
#' which SDTM variables are referenced by no ADaM variable at all? These are the
#' dead or unused sources in a submission, the columns a derivation never reads.
#'
#' @details
#' A trace model records derivations as edges from a derived variable to its
#' source. An SDTM variable is used when at least one ADaM variable maps to it,
#' so this walks the same reverse adjacency as [trace_impact()]: it counts, for
#' every SDTM variable, how many derivations point at it. ADaM-to-SDTM mappings
#' are the only edges that reach an SDTM node, so `adam_derivations` never adds
#' SDTM references; it is accepted for parity with the rest of the engine and
#' passed through unchanged. This is a pure diagnostic and does not affect trace
#' levels, coverage, or any scoring.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param adam_derivations Optional data.frame of ADaM-to-ADaM derivations with
#'   columns `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
#'   [trace_chains()]. Accepted for parity; it does not change which SDTM
#'   variables are considered used.
#'
#' @return A tibble with one row per SDTM variable: `dataset`, `variable`,
#'   `used_count` (how many ADaM variables map to it), and `referenced` (whether
#'   `used_count` is above zero). Unused sources are listed first, then by
#'   dataset and variable. Zero rows means the model has no SDTM variables.
#'
#' @seealso [trace_impact()] for the forward question (what a source feeds),
#'   and [trace_problems()] for ADaM-side traceability issues.
#'
#' @examples
#' adam <- data.frame(
#'   dataset = "ADSL", variable = "AGE", label = "Age"
#' )
#' sdtm <- data.frame(
#'   dataset = "DM", variable = c("AGE", "SEX"),
#'   label = c("Age", "Sex")
#' )
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = "AGE",
#'   sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1
#' )
#' tm <- build_trace_model(adam, sdtm, mapping = map)
#' # DM.SEX is never referenced by an ADaM variable.
#' sdtm_utilization(tm)
#'
#' # With the bundled example metadata from r4subdata.
#' if (requireNamespace("r4subdata", quietly = TRUE)) {
#'   tm2 <- build_trace_model(
#'     r4subdata::adam_metadata,
#'     r4subdata::sdtm_metadata,
#'     mapping = r4subdata::trace_mapping
#'   )
#'   util <- sdtm_utilization(tm2)
#'   # Unused SDTM sources.
#'   util[!util$referenced, ]
#' }
#'
#' @export
sdtm_utilization <- function(trace_model, adam_derivations = NULL) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }

  nodes <- trace_model$nodes
  sdtm_nodes <- nodes[nodes$role == "sdtm" & nodes$node_type == "variable", ,
                      drop = FALSE]
  if (nrow(sdtm_nodes) == 0L) {
    return(tibble::tibble(
      dataset    = character(0),
      variable   = character(0),
      used_count = integer(0),
      referenced = logical(0)
    ))
  }

  edges <- build_chain_edges(trace_model, adam_derivations)
  # How many derivations point at each node (its in-degree over reverse edges).
  used <- table(edges$to)

  sdtm_keys  <- make_key("sdtm", sdtm_nodes$dataset, sdtm_nodes$variable)
  used_count <- as.integer(unname(used[sdtm_keys]))
  used_count[is.na(used_count)] <- 0L

  out <- tibble::tibble(
    dataset    = sdtm_nodes$dataset,
    variable   = sdtm_nodes$variable,
    used_count = used_count,
    referenced = used_count > 0L
  )
  out <- out[order(out$referenced, out$dataset, out$variable), , drop = FALSE]
  rownames(out) <- NULL
  out
}
