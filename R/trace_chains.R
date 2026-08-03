#' Follow Multi-Step Derivation Chains
#'
#' Traces each ADaM variable back to its ultimate source through chains of any
#' depth, not just a single ADaM-to-SDTM hop. Real submissions often derive an
#' ADaM variable from another ADaM variable that is itself derived from SDTM
#' (for example an `ADAE` variable built from `ADSL`, which in turn comes from
#' `DM`). Shallow tracing misses those links and understates coverage.
#'
#' @details
#' The ADaM-to-SDTM links come from the trace model's edges. ADaM-to-ADaM links
#' are supplied through `adam_derivations`, a data.frame with columns
#' `from_dataset`, `from_var`, `to_dataset`, `to_var`, where `from` is the
#' derived variable and `to` is its source. Each ADaM variable is walked toward
#' its sources until the path reaches an SDTM variable (grounded), dead-ends at
#' an ADaM variable with no further source (ungrounded), revisits a node
#' (a cycle), or reaches `trace_depth` hops.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param adam_derivations Optional data.frame of ADaM-to-ADaM derivations with
#'   columns `from_dataset`, `from_var`, `to_dataset`, `to_var`.
#' @param trace_depth Maximum number of hops to follow, a positive integer.
#'   Default `3`.
#'
#' @return A tibble with one row per ADaM variable: `adam_dataset`, `adam_var`,
#'   `max_depth` (longest chain in hops), `grounded` (a path reaches SDTM),
#'   `terminal_source`, `has_cycle`, `truncated` (a path hit `trace_depth`),
#'   `n_paths`, and `longest_chain` (a readable path string).
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
#' trace_chains(tm, adam_derivations = deriv)
#'
#' @export
trace_chains <- function(trace_model, adam_derivations = NULL, trace_depth = 3L) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }
  if (!is.numeric(trace_depth) || length(trace_depth) != 1L || trace_depth < 1) {
    cli::cli_abort("{.arg trace_depth} must be a positive integer.")
  }
  trace_depth <- as.integer(trace_depth)

  nodes <- trace_model$nodes
  edges <- build_chain_edges(trace_model, adam_derivations)
  edges_by_from <- split(edges$to, edges$from)

  adam_nodes <- nodes[nodes$role == "adam" & nodes$node_type == "variable", ,
                      drop = FALSE]
  if (nrow(adam_nodes) == 0L) {
    return(empty_chain_tibble())
  }

  any_cycle <- FALSE
  rows <- lapply(seq_len(nrow(adam_nodes)), function(i) {
    start <- make_key("adam", adam_nodes$dataset[i], adam_nodes$variable[i])
    walked <- walk_chain(edges_by_from, start, trace_depth)
    if (walked$has_cycle) any_cycle <<- TRUE

    paths <- walked$paths
    depths <- vapply(paths, function(p) length(p) - 1L, integer(1))
    ends   <- vapply(paths, function(p) p[length(p)], character(1))
    grounded_path <- vapply(ends, key_role, character(1)) == "sdtm"

    # Representative path: prefer a grounded one, then the longest.
    order_idx <- order(!grounded_path, -depths)
    best <- paths[[order_idx[1]]]

    tibble::tibble(
      adam_dataset    = adam_nodes$dataset[i],
      adam_var        = adam_nodes$variable[i],
      max_depth       = if (length(depths)) max(depths) else 0L,
      grounded        = any(grounded_path),
      terminal_source = key_label(best[length(best)]),
      has_cycle       = walked$has_cycle,
      truncated       = walked$truncated,
      n_paths         = length(paths),
      longest_chain   = paste(vapply(best, key_label, character(1)),
                              collapse = " -> ")
    )
  })

  if (any_cycle) {
    cli::cli_warn(
      "Circular derivation reference detected; affected chains stop at the cycle."
    )
  }

  dplyr::bind_rows(rows)
}


#' Plot a Derivation Graph
#'
#' Draws the derivation graph behind [trace_chains()] using `igraph`: ADaM and
#' SDTM variables as nodes, derivation links as directed edges.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param adam_derivations Optional ADaM-to-ADaM derivations, as in
#'   [trace_chains()].
#' @param ... Passed to [igraph::plot.igraph()].
#'
#' @return The `igraph` object, invisibly.
#'
#' @examples
#' \dontrun{
#' plot_trace_graph(tm, adam_derivations = deriv)
#' }
#'
#' @export
plot_trace_graph <- function(trace_model, adam_derivations = NULL, ...) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg igraph} is required for {.fn plot_trace_graph}.")
  }

  edges <- build_chain_edges(trace_model, adam_derivations)
  el <- cbind(vapply(edges$from, key_label, character(1)),
              vapply(edges$to, key_label, character(1)))
  roles <- c(stats::setNames(vapply(edges$from, key_role, character(1)),
                             vapply(edges$from, key_label, character(1))),
             stats::setNames(vapply(edges$to, key_role, character(1)),
                             vapply(edges$to, key_label, character(1))))

  g <- igraph::graph_from_edgelist(el, directed = TRUE)
  vrole <- roles[igraph::V(g)$name]
  igraph::V(g)$color <- ifelse(vrole == "sdtm", "#F39C12", "#2C6DB5")

  igraph::plot.igraph(g, vertex.label.cex = 0.8, edge.arrow.size = 0.5, ...)
  invisible(g)
}


# --- Internal helpers ---------------------------------------------------

# Node key packs role, dataset, and variable so ADaM ADSL.AGE and SDTM DM.AGE
# stay distinct. The separator is a control character that will not appear in a
# dataset or variable name.
make_key <- function(role, dataset, variable) {
  paste(role, dataset, variable, sep = "\x1f")
}
key_parts <- function(key) strsplit(key, "\x1f", fixed = TRUE)[[1]]
key_role  <- function(key) key_parts(key)[1]
key_label <- function(key) {
  p <- key_parts(key)
  paste0(p[2], ".", p[3])
}

empty_chain_tibble <- function() {
  tibble::tibble(
    adam_dataset = character(0), adam_var = character(0),
    max_depth = integer(0), grounded = logical(0),
    terminal_source = character(0), has_cycle = logical(0),
    truncated = logical(0), n_paths = integer(0), longest_chain = character(0)
  )
}

# Build the unified directed edge list (derived variable -> source) on node
# keys, combining the model's ADaM-to-SDTM edges with optional ADaM-to-ADaM
# derivations.
build_chain_edges <- function(trace_model, adam_derivations) {
  nodes <- trace_model$nodes
  lut <- stats::setNames(
    make_key(nodes$role, nodes$dataset, nodes$variable),
    nodes$node_id
  )

  e <- trace_model$edges
  from <- unname(lut[e$from_id])
  to   <- unname(lut[e$to_id])
  base <- data.frame(from = from, to = to, stringsAsFactors = FALSE)
  base <- base[!is.na(base$from) & !is.na(base$to), , drop = FALSE]

  if (!is.null(adam_derivations)) {
    ad <- normalize_adam_derivations(
      adam_derivations,
      uppercase = isTRUE(trace_model$config$uppercase_datasets)
    )
    dev <- data.frame(
      from = make_key("adam", ad$from_dataset, ad$from_var),
      to   = make_key("adam", ad$to_dataset, ad$to_var),
      stringsAsFactors = FALSE
    )
    base <- rbind(base, dev)
  }

  unique(base)
}

normalize_adam_derivations <- function(df, uppercase) {
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg adam_derivations} must be a data.frame.")
  }
  required <- c("from_dataset", "from_var", "to_dataset", "to_var")
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "{.arg adam_derivations} is missing column(s): {.val {missing_cols}}."
    )
  }
  for (col in required) df[[col]] <- stringr::str_trim(as.character(df[[col]]))
  if (uppercase) {
    df$from_dataset <- stringr::str_to_upper(df$from_dataset)
    df$to_dataset   <- stringr::str_to_upper(df$to_dataset)
  }
  df
}

# Depth-first walk from a start node toward sources. Returns every complete
# path, whether any path hit a cycle, and whether any path was cut at max_depth.
walk_chain <- function(edges_by_from, start, max_depth) {
  paths     <- list()
  has_cycle <- FALSE
  truncated <- FALSE

  recurse <- function(node, path, depth) {
    nexts <- edges_by_from[[node]]
    if (is.null(nexts) || length(nexts) == 0L) {
      paths[[length(paths) + 1L]] <<- path
      return(invisible())
    }
    if (depth >= max_depth) {
      truncated <<- TRUE
      paths[[length(paths) + 1L]] <<- path
      return(invisible())
    }
    for (nx in nexts) {
      if (nx %in% path) {
        has_cycle <<- TRUE
        paths[[length(paths) + 1L]] <<- c(path, nx)
        next
      }
      recurse(nx, c(path, nx), depth + 1L)
    }
  }

  recurse(start, start, 0L)
  list(paths = paths, has_cycle = has_cycle, truncated = truncated)
}
