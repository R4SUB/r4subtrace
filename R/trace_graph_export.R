#' Export the Derivation Graph to a Portable Text Format
#'
#' Serializes the derivation graph behind [trace_chains()] and [trace_impact()]
#' to a portable text format: Graphviz DOT, Mermaid, or GraphML. Unlike
#' [plot_trace_graph()], which needs `igraph` and only renders interactively,
#' this writes the graph as text that can be committed to version control,
#' embedded in an ADRG or vignette, rendered by Graphviz, or opened in a graph
#' editor such as yEd.
#'
#' @details
#' Nodes are ADaM and SDTM variables; a directed edge runs from a derived
#' variable to its source (`A -> B` reads "A is derived from B"), the same
#' direction used throughout the engine. ADaM-to-SDTM links come from the trace
#' model's mapping edges; ADaM-to-ADaM links are added when supplied through
#' `adam_derivations`, exactly as in [trace_chains()]. Every variable node in
#' the model is emitted, so orphan ADaM variables (no outgoing edge) and unused
#' SDTM sources (no incoming edge) appear as isolated nodes unless
#' `include_isolated = FALSE`. Node roles are recorded so a renderer can colour
#' ADaM and SDTM variables differently. This is a pure serialization: it does
#' not change trace levels, coverage, or any scoring.
#'
#' @param trace_model A `trace_model` from [build_trace_model()].
#' @param format One of `"dot"` (Graphviz), `"mermaid"`, or `"graphml"`.
#' @param adam_derivations Optional data.frame of ADaM-to-ADaM derivations with
#'   columns `from_dataset`, `from_var`, `to_dataset`, `to_var`, as in
#'   [trace_chains()].
#' @param file Optional output file path. When supplied, the serialized graph is
#'   written there and the text is returned invisibly; otherwise the text is
#'   returned (a single string, one line per `\n`).
#' @param include_isolated Logical; when `TRUE` (the default) variable nodes
#'   with no derivation edge are included as isolated nodes. When `FALSE` only
#'   nodes that take part in at least one edge are emitted.
#'
#' @return A length-one character string containing the serialized graph,
#'   returned invisibly when `file` is supplied.
#'
#' @seealso [plot_trace_graph()] for interactive plotting with `igraph`,
#'   [trace_chains()] for the graph model itself.
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
#' # Graphviz DOT
#' cat(export_trace_graph(tm, "dot", adam_derivations = deriv))
#'
#' # Mermaid, for a Markdown document
#' cat(export_trace_graph(tm, "mermaid", adam_derivations = deriv))
#'
#' @export
export_trace_graph <- function(trace_model,
                               format = c("dot", "mermaid", "graphml"),
                               adam_derivations = NULL,
                               file = NULL,
                               include_isolated = TRUE) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }
  format <- rlang::arg_match(format)
  if (!is.logical(include_isolated) || length(include_isolated) != 1L ||
      is.na(include_isolated)) {
    cli::cli_abort("{.arg include_isolated} must be a single {.code TRUE}/{.code FALSE}.")
  }

  edges <- build_chain_edges(trace_model, adam_derivations)

  nodes <- trace_model$nodes
  model_keys <- make_key(nodes$role, nodes$dataset, nodes$variable)

  # Node universe: every variable node in the model, plus any edge endpoint
  # not present as a node (e.g. an adam_derivations entry for an unlisted var).
  edge_keys <- unique(c(edges$from, edges$to))
  node_keys <- unique(c(model_keys, edge_keys))

  if (!include_isolated) {
    node_keys <- node_keys[node_keys %in% edge_keys]
  }

  # Stable, collision-free ids independent of the (free-text) labels.
  ids <- stats::setNames(paste0("n", seq_along(node_keys)), node_keys)
  roles  <- vapply(node_keys, key_role, character(1))
  labels <- vapply(node_keys, key_label, character(1))

  text <- switch(
    format,
    dot     = graph_to_dot(ids, labels, roles, edges),
    mermaid = graph_to_mermaid(ids, labels, roles, edges),
    graphml = graph_to_graphml(ids, labels, roles, edges)
  )

  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L) {
      cli::cli_abort("{.arg file} must be a single file path.")
    }
    writeLines(text, file)
    cli::cli_alert_success("Wrote {format} derivation graph to {.file {file}}.")
    return(invisible(text))
  }
  text
}


# --- Serializers --------------------------------------------------------

# A derivation edge runs from the derived variable to its source. Keep only
# edges whose endpoints are in the emitted node set (matters when
# include_isolated = FALSE never drops edge endpoints, but guards all the same).
keep_edges <- function(edges, ids) {
  edges[edges$from %in% names(ids) & edges$to %in% names(ids), , drop = FALSE]
}

role_fill <- function(role) ifelse(role == "sdtm", "#F39C12", "#2C6DB5")

graph_to_dot <- function(ids, labels, roles, edges) {
  edges <- keep_edges(edges, ids)
  node_lines <- sprintf(
    "  %s [label=\"%s\", fillcolor=\"%s\", style=filled, shape=box];",
    ids, dot_escape(labels), role_fill(roles)
  )
  edge_lines <- if (nrow(edges) > 0L) {
    sprintf("  %s -> %s;", ids[edges$from], ids[edges$to])
  } else {
    character(0)
  }
  paste(c(
    "digraph trace {",
    "  rankdir=LR;",
    "  node [fontname=\"Helvetica\"];",
    node_lines,
    edge_lines,
    "}"
  ), collapse = "\n")
}

graph_to_mermaid <- function(ids, labels, roles, edges) {
  edges <- keep_edges(edges, ids)
  node_lines <- sprintf("  %s[\"%s\"]", ids, mermaid_escape(labels))
  edge_lines <- if (nrow(edges) > 0L) {
    sprintf("  %s --> %s", ids[edges$from], ids[edges$to])
  } else {
    character(0)
  }
  class_lines <- c(
    "  classDef adam fill:#2C6DB5,stroke:#1b4a7a,color:#ffffff;",
    "  classDef sdtm fill:#F39C12,stroke:#9a6207,color:#ffffff;"
  )
  adam_ids <- ids[roles == "adam"]
  sdtm_ids <- ids[roles == "sdtm"]
  assign_lines <- c(
    if (length(adam_ids)) sprintf("  class %s adam;", paste(adam_ids, collapse = ",")),
    if (length(sdtm_ids)) sprintf("  class %s sdtm;", paste(sdtm_ids, collapse = ","))
  )
  paste(c(
    "flowchart LR",
    node_lines,
    edge_lines,
    class_lines,
    assign_lines
  ), collapse = "\n")
}

graph_to_graphml <- function(ids, labels, roles, edges) {
  edges <- keep_edges(edges, ids)
  node_lines <- sprintf(
    paste0(
      "    <node id=\"%s\">",
      "<data key=\"label\">%s</data>",
      "<data key=\"role\">%s</data></node>"
    ),
    ids, xml_escape(labels), xml_escape(roles)
  )
  edge_lines <- if (nrow(edges) > 0L) {
    sprintf(
      "    <edge id=\"e%d\" source=\"%s\" target=\"%s\"/>",
      seq_len(nrow(edges)), ids[edges$from], ids[edges$to]
    )
  } else {
    character(0)
  }
  paste(c(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">",
    "  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>",
    "  <key id=\"role\" for=\"node\" attr.name=\"role\" attr.type=\"string\"/>",
    "  <graph edgedefault=\"directed\">",
    node_lines,
    edge_lines,
    "  </graph>",
    "</graphml>"
  ), collapse = "\n")
}


# --- Escaping -----------------------------------------------------------

dot_escape <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  gsub("\"", "\\\"", x, fixed = TRUE)
}

mermaid_escape <- function(x) {
  # Mermaid renders node labels as HTML, so the HTML metacharacters must be
  # replaced with the entities it understands inside a "..." node label. Escape
  # the ampersand first so the entities emitted below are not re-escaped.
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  gsub("'", "&apos;", x, fixed = TRUE)
}
