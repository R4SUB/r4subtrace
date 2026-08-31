#' Impact Analysis for a Changed Source Variable
#'
#' Answers the question a data team asks before touching a source variable: if
#' this changes, what downstream ADaM variables are affected? Given a trace
#' model and a variable that is about to change, `trace_impact()` follows the
#' derivation graph in reverse and returns every variable that derives from it,
#' directly or through a chain.
#'
#' @details
#' The trace model records derivations as edges from a derived variable to its
#' source. Impact analysis walks those edges backwards from the changed variable
#' to find its dependents. ADaM-to-ADaM derivations are included when supplied
#' through `adam_derivations`, exactly as in [trace_chains()], so multi-step
#' impact (an `ADTTE` variable built from an `ADSL` variable built from `DM`) is
#' captured. Each dependent is reported once, at its shortest distance from the
#' change, with a readable path back to it. Circular references are handled and
#' do not loop.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param changed A single variable identifier as `"DATASET.VARIABLE"`, for
#'   example `"DM.AGE"` or `"ADSL.AGE"`.
#' @param adam_derivations Optional data.frame of ADaM-to-ADaM derivations with
#'   columns `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
#'   [trace_chains()].
#' @param max_depth Optional maximum number of hops to report. `Inf` (the
#'   default) reports the full transitive set.
#'
#' @return A tibble with one row per impacted variable: `dataset`, `variable`,
#'   `role`, `depth` (hops from the change), and `path` (a readable derivation
#'   path from the impacted variable back to the changed one). Rows are ordered
#'   nearest first. Zero rows means nothing derives from the variable. The
#'   result carries a `"changed"` attribute with the resolved identifier.
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
#' # If DM.AGE changes, what is affected?
#' trace_impact(tm, "DM.AGE", adam_derivations = deriv)
#'
#' @export
trace_impact <- function(trace_model, changed, adam_derivations = NULL,
                         max_depth = Inf) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }
  if (!is.character(changed) || length(changed) != 1L || is.na(changed) ||
      !nzchar(changed)) {
    cli::cli_abort("{.arg changed} must be a single {.val DATASET.VARIABLE} string.")
  }
  if (!(is.numeric(max_depth) && length(max_depth) == 1L && max_depth >= 1)) {
    cli::cli_abort("{.arg max_depth} must be a single number >= 1 (or Inf).")
  }

  nodes <- trace_model$nodes
  node_keys   <- make_key(nodes$role, nodes$dataset, nodes$variable)
  node_labels <- paste0(nodes$dataset, ".", nodes$variable)

  target_idx <- which(node_labels == changed)
  if (length(target_idx) == 0L) {
    cli::cli_abort(c(
      "Variable {.val {changed}} is not in the trace model.",
      "i" = "Use the {.val DATASET.VARIABLE} form, for example {.val DM.AGE}."
    ))
  }
  targets <- node_keys[target_idx]

  edges <- build_chain_edges(trace_model, adam_derivations)
  # Reverse adjacency: for a source node, who derives from it.
  dependents_of <- split(edges$from, edges$to)

  recorded <- new.env(parent = emptyenv())   # key -> list(depth, path)

  # Breadth-first over reverse edges; first visit is the shortest depth.
  frontier <- lapply(targets, function(t) list(node = t, path = t))
  depth <- 0L
  while (length(frontier) > 0L && depth < max_depth) {
    depth <- depth + 1L
    next_frontier <- list()
    for (item in frontier) {
      deps <- dependents_of[[item$node]]
      if (is.null(deps)) next
      for (d in deps) {
        if (d %in% item$path) next                 # cycle guard
        if (d %in% targets) next                    # never list the change itself
        if (!is.null(recorded[[d]])) next          # already at a shorter depth
        newpath <- c(d, item$path)                 # d -> ... -> changed
        recorded[[d]] <- list(depth = depth, path = newpath)
        next_frontier[[length(next_frontier) + 1L]] <- list(node = d, path = newpath)
      }
    }
    frontier <- next_frontier
  }

  keys <- ls(recorded)
  if (length(keys) == 0L) {
    out <- tibble::tibble(
      dataset = character(0), variable = character(0), role = character(0),
      depth = integer(0), path = character(0)
    )
    attr(out, "changed") <- changed
    return(out)
  }

  parts <- lapply(keys, key_parts)
  depths <- unname(vapply(keys, function(k) recorded[[k]]$depth, integer(1)))
  paths  <- unname(vapply(keys, function(k) {
    paste(vapply(recorded[[k]]$path, key_label, character(1)), collapse = " -> ")
  }, character(1)))

  out <- tibble::tibble(
    dataset  = vapply(parts, `[`, character(1), 2L),
    variable = vapply(parts, `[`, character(1), 3L),
    role     = vapply(parts, `[`, character(1), 1L),
    depth    = depths,
    path     = paths
  )
  out <- out[order(out$depth, out$dataset, out$variable), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "changed") <- changed
  out
}
