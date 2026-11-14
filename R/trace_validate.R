#' Validate the Structural Integrity of a Derivation Graph
#'
#' Runs structural integrity checks over the derivation graph behind
#' [trace_chains()] and [trace_impact()] and returns a tidy diagnostic report.
#' These are purely structural graph checks, not traceability scoring: they say
#' whether the graph itself is well formed before any coverage or level is read
#' off it.
#'
#' @details
#' The graph is the same one the rest of the engine uses: nodes are ADaM and
#' SDTM variables and a directed edge runs from a derived variable to its source
#' (`A -> B` reads "A is derived from B"). ADaM-to-SDTM edges come from the trace
#' model's mapping; ADaM-to-ADaM edges are added when supplied through
#' `adam_derivations`, exactly as in [trace_chains()]. Four checks are reported,
#' one row per node per failing check:
#'
#' - **`cycle`**: the node is part of a circular derivation chain (a variable
#'   that derives, directly or transitively, from itself). Found with a standard
#'   strongly-connected-component search, so every node in the cycle is flagged.
#' - **`dangling_edge`**: a derivation edge (always from `adam_derivations`)
#'   names this node as a source or dependent, but it is not present as a node in
#'   the trace model. The edge points at something that does not exist.
#' - **`orphan`**: the variable takes part in no derivation edge at all (an
#'   isolated node) - an ADaM variable mapped to nothing, or an SDTM variable
#'   read by nothing.
#' - **`disconnected`**: the node belongs to a connected component (two or more
#'   nodes joined by derivations) that contains no SDTM variable, so no path in
#'   that component can ever reach a source.
#'
#' A node can appear in more than one check. Cycle detection, reachability, and
#' connected components are standard graph algorithms; nothing here invents a
#' domain weight, threshold, or score.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param adam_derivations Optional data.frame of ADaM-to-ADaM derivations with
#'   columns `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
#'   [trace_chains()].
#'
#' @return A tibble with one row per node per failing check: `check` (one of
#'   `"cycle"`, `"dangling_edge"`, `"orphan"`, `"disconnected"`), `dataset`,
#'   `variable`, `role`, and a readable `detail`. Zero rows means the graph is
#'   structurally clean.
#'
#' @seealso [trace_lineage()] for ancestry and dependent queries,
#'   [trace_problems()] for ADaM-side traceability issues, [trace_chains()] for
#'   the graph model itself.
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
#'
#' # A clean mapping reports nothing except the orphan ADAE.AAGE.
#' validate_trace_graph(tm)
#'
#' # A circular derivation is detected.
#' cyc <- data.frame(
#'   from_dataset = c("ADSL", "ADAE"), from_var = c("AGE", "AAGE"),
#'   to_dataset   = c("ADAE", "ADSL"), to_var   = c("AAGE", "AGE")
#' )
#' validate_trace_graph(tm, adam_derivations = cyc)
#'
#' @export
validate_trace_graph <- function(trace_model, adam_derivations = NULL) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }

  nodes <- trace_model$nodes
  var_nodes <- nodes[nodes$node_type == "variable", , drop = FALSE]
  model_keys <- make_key(var_nodes$role, var_nodes$dataset, var_nodes$variable)

  edges <- build_chain_edges(trace_model, adam_derivations)

  parts <- list()

  # --- dangling edges: an endpoint that is not a node in the model ---------
  endpoints <- unique(c(edges$from, edges$to))
  dangling  <- endpoints[!(endpoints %in% model_keys)]
  if (length(dangling) > 0L) {
    parts[[length(parts) + 1L]] <- validation_rows(
      dangling, "dangling_edge",
      "named by a derivation edge but absent from the trace model"
    )
  }

  # --- cycles: nodes in a strongly connected component or self-loop ---------
  if (nrow(edges) > 0L) {
    adj_fwd <- split(edges$to, edges$from)
    edge_nodes <- unique(c(edges$from, edges$to))
    sccs <- scc_tarjan(adj_fwd, edge_nodes)
    self_loops <- edges$from[edges$from == edges$to]

    cyc_parts <- list()
    for (comp in sccs) {
      is_cycle <- length(comp) > 1L || comp[1] %in% self_loops
      if (!is_cycle) next
      members <- paste(sort(vapply(comp, key_label, character(1))), collapse = ", ")
      detail <- if (length(comp) > 1L) {
        sprintf("part of a circular derivation chain among: %s", members)
      } else {
        sprintf("%s derives from itself", key_label(comp[1]))
      }
      cyc_parts[[length(cyc_parts) + 1L]] <- validation_rows(comp, "cycle", detail)
    }
    if (length(cyc_parts) > 0L) {
      parts[[length(parts) + 1L]] <- dplyr::bind_rows(cyc_parts)
    }
  }

  # --- orphans: model nodes that take part in no edge ----------------------
  incident <- unique(c(edges$from, edges$to))
  orphan_keys <- model_keys[!(model_keys %in% incident)]
  if (length(orphan_keys) > 0L) {
    parts[[length(parts) + 1L]] <- validation_rows(
      orphan_keys, "orphan",
      "isolated node: takes part in no derivation edge"
    )
  }

  # --- disconnected components with no SDTM source -------------------------
  valid_edges <- edges[edges$from %in% model_keys & edges$to %in% model_keys, ,
                       drop = FALSE]
  comps <- weak_components(model_keys, valid_edges)
  disc_parts <- list()
  for (comp in comps) {
    if (length(comp) < 2L) next                      # singletons are orphans
    if (any(vapply(comp, key_role, character(1)) == "sdtm")) next
    disc_parts[[length(disc_parts) + 1L]] <- validation_rows(
      comp, "disconnected",
      sprintf("in a %d-node derivation component with no SDTM source",
              length(comp))
    )
  }
  if (length(disc_parts) > 0L) {
    parts[[length(parts) + 1L]] <- dplyr::bind_rows(disc_parts)
  }

  if (length(parts) == 0L) {
    return(empty_validation_tibble())
  }

  out <- dplyr::bind_rows(parts)
  out <- out[order(out$check, out$dataset, out$variable), , drop = FALSE]
  rownames(out) <- NULL
  out
}


#' Trace the Lineage of a Variable Through the Derivation Graph
#'
#' Given a single variable, walks the derivation graph behind [trace_chains()]
#' and returns its lineage: either every upstream source it derives from
#' (its full ancestry) or every downstream variable that derives from it (its
#' dependents). This is the general path query over the graph; [trace_impact()]
#' is the special case of downstream dependents of a source variable.
#'
#' @details
#' A directed edge runs from a derived variable to its source. `trace_lineage()`
#' follows those edges in one of two directions from the queried node:
#'
#' - `direction = "upstream"` follows edges forward, toward sources, and returns
#'   the transitive set of everything the variable is derived from, down to the
#'   SDTM variables that ground it.
#' - `direction = "downstream"` follows edges in reverse and returns the
#'   transitive set of variables that depend on it.
#'
#' ADaM-to-ADaM derivations are included when supplied through
#' `adam_derivations`, exactly as in [trace_chains()], so multi-step lineage is
#' captured. Each related variable is reported once, at its shortest distance
#' from the queried node, with a readable path that reads outward from the node.
#' Circular references are handled and do not loop.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param node A single variable identifier as `"DATASET.VARIABLE"`, for example
#'   `"ADSL.AGE"`.
#' @param direction One of `"upstream"` (sources the node derives from, the
#'   default) or `"downstream"` (variables that derive from the node).
#' @param adam_derivations Optional data.frame of ADaM-to-ADaM derivations with
#'   columns `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
#'   [trace_chains()].
#' @param max_depth Optional maximum number of hops to report. `Inf` (the
#'   default) reports the full transitive lineage.
#'
#' @return A tibble with one row per related variable: `dataset`, `variable`,
#'   `role`, `depth` (hops from the queried node), and `path` (a readable
#'   derivation path reading outward from the node). Rows are ordered nearest
#'   first. Zero rows means the node has no lineage in the requested direction.
#'   The result carries `"node"` and `"direction"` attributes.
#'
#' @seealso [trace_impact()] for downstream impact of a source variable,
#'   [trace_chains()] for per-variable chain summaries,
#'   [validate_trace_graph()] for structural integrity checks.
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
#'
#' # Where does ADAE.AAGE come from?
#' trace_lineage(tm, "ADAE.AAGE", "upstream", adam_derivations = deriv)
#'
#' # What depends on DM.AGE?
#' trace_lineage(tm, "DM.AGE", "downstream", adam_derivations = deriv)
#'
#' @export
trace_lineage <- function(trace_model, node,
                          direction = c("upstream", "downstream"),
                          adam_derivations = NULL, max_depth = Inf) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }
  direction <- rlang::arg_match(direction)
  if (!is.character(node) || length(node) != 1L || is.na(node) || !nzchar(node)) {
    cli::cli_abort("{.arg node} must be a single {.val DATASET.VARIABLE} string.")
  }
  if (!(is.numeric(max_depth) && length(max_depth) == 1L && max_depth >= 1)) {
    cli::cli_abort("{.arg max_depth} must be a single number >= 1 (or Inf).")
  }

  nodes <- trace_model$nodes
  node_keys   <- make_key(nodes$role, nodes$dataset, nodes$variable)
  node_labels <- paste0(nodes$dataset, ".", nodes$variable)

  target_idx <- which(node_labels == node)
  if (length(target_idx) == 0L) {
    cli::cli_abort(c(
      "Variable {.val {node}} is not in the trace model.",
      "i" = "Use the {.val DATASET.VARIABLE} form, for example {.val ADSL.AGE}."
    ))
  }
  targets <- node_keys[target_idx]

  edges <- build_chain_edges(trace_model, adam_derivations)
  # Upstream follows edges toward sources; downstream follows them in reverse.
  adj <- if (direction == "upstream") {
    split(edges$to, edges$from)
  } else {
    split(edges$from, edges$to)
  }

  recorded <- new.env(parent = emptyenv())   # key -> list(depth, path)

  # Breadth-first from the queried node; first visit is the shortest depth.
  frontier <- lapply(targets, function(t) list(node = t, path = t))
  depth <- 0L
  while (length(frontier) > 0L && depth < max_depth) {
    depth <- depth + 1L
    next_frontier <- list()
    for (item in frontier) {
      nexts <- adj[[item$node]]
      if (is.null(nexts)) next
      for (nx in nexts) {
        if (nx %in% item$path) next              # cycle guard
        if (nx %in% targets) next                # never list the node itself
        if (!is.null(recorded[[nx]])) next       # already at a shorter depth
        newpath <- c(item$path, nx)              # node -> ... -> nx
        recorded[[nx]] <- list(depth = depth, path = newpath)
        next_frontier[[length(next_frontier) + 1L]] <-
          list(node = nx, path = newpath)
      }
    }
    frontier <- next_frontier
  }

  keys <- ls(recorded)
  if (length(keys) == 0L) {
    out <- empty_lineage_tibble()
    attr(out, "node") <- node
    attr(out, "direction") <- direction
    return(out)
  }

  parts  <- lapply(keys, key_parts)
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
  attr(out, "node") <- node
  attr(out, "direction") <- direction
  out
}


# --- Internal helpers ---------------------------------------------------

empty_validation_tibble <- function() {
  tibble::tibble(
    check = character(0), dataset = character(0), variable = character(0),
    role = character(0), detail = character(0)
  )
}

empty_lineage_tibble <- function() {
  tibble::tibble(
    dataset = character(0), variable = character(0), role = character(0),
    depth = integer(0), path = character(0)
  )
}

# Turn a vector of node keys into validation rows for one check.
validation_rows <- function(keys, check, detail) {
  parts <- lapply(keys, key_parts)
  tibble::tibble(
    check    = check,
    dataset  = vapply(parts, `[`, character(1), 2L),
    variable = vapply(parts, `[`, character(1), 3L),
    role     = vapply(parts, `[`, character(1), 1L),
    detail   = detail
  )
}

# Strongly connected components (Tarjan). Returns a list of character vectors
# of node keys; a component of length > 1, or a single node with a self-loop,
# is a directed cycle.
scc_tarjan <- function(adj, nodes) {
  idx      <- new.env(parent = emptyenv())
  low      <- new.env(parent = emptyenv())
  on_stack <- new.env(parent = emptyenv())
  counter  <- 0L
  stack    <- character(0)
  sccs     <- list()

  strongconnect <- function(v) {
    assign(v, counter, envir = idx)
    assign(v, counter, envir = low)
    counter <<- counter + 1L
    stack <<- c(stack, v)
    assign(v, TRUE, envir = on_stack)

    for (w in adj[[v]]) {
      if (is.null(idx[[w]])) {
        strongconnect(w)
        assign(v, min(low[[v]], low[[w]]), envir = low)
      } else if (isTRUE(on_stack[[w]])) {
        assign(v, min(low[[v]], idx[[w]]), envir = low)
      }
    }

    if (low[[v]] == idx[[v]]) {
      comp <- character(0)
      repeat {
        w <- stack[length(stack)]
        stack <<- stack[-length(stack)]
        assign(w, FALSE, envir = on_stack)
        comp <- c(comp, w)
        if (identical(w, v)) break
      }
      sccs[[length(sccs) + 1L]] <<- comp
    }
  }

  for (v in nodes) {
    if (is.null(idx[[v]])) strongconnect(v)
  }
  sccs
}

# Weakly connected components over an undirected view of the edges. Returns a
# list of character vectors of node keys, one per component, covering every key
# in `node_keys`.
weak_components <- function(node_keys, edges) {
  parent <- new.env(parent = emptyenv())
  for (k in node_keys) assign(k, k, envir = parent)

  find <- function(x) {
    while (!identical(parent[[x]], x)) x <- parent[[x]]
    x
  }
  union <- function(a, b) {
    ra <- find(a); rb <- find(b)
    if (!identical(ra, rb)) assign(ra, rb, envir = parent)
  }

  if (nrow(edges) > 0L) {
    for (i in seq_len(nrow(edges))) union(edges$from[i], edges$to[i])
  }

  roots <- vapply(node_keys, find, character(1))
  unname(split(node_keys, roots))
}
