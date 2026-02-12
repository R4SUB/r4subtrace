#' Build a Trace Model
#'
#' Constructs a directed trace model (nodes + edges + diagnostics) from
#' ADaM metadata, SDTM metadata, and an optional mapping sheet.
#'
#' @param adam_meta A data.frame of ADaM variable metadata. Must contain
#'   `dataset` and `variable` columns.
#' @param sdtm_meta A data.frame of SDTM variable metadata. Must contain
#'   `dataset` and `variable` columns.
#' @param mapping An optional data.frame describing ADaM-to-SDTM mappings.
#'   Must contain `adam_dataset`, `adam_var`, `sdtm_domain`, `sdtm_var`.
#' @param spec Reserved for future use (ADaM spec ingestion).
#' @param config A `trace_config` object from [trace_config_default()].
#'
#' @return A list of class `"trace_model"` with elements:
#'   - `nodes`: tibble of asset nodes (datasets and variables)
#'   - `edges`: tibble of relationships between nodes
#'   - `diagnostics`: list of tibbles (`orphans`, `ambiguities`, `conflicts`)
#'   - `config`: the configuration used
#'
#' @examples
#' adam_meta <- data.frame(
#'   dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGE"),
#'   label = c("Study ID", "Unique Subject ID", "Age")
#' )
#' sdtm_meta <- data.frame(
#'   dataset = "DM", variable = c("STUDYID", "USUBJID", "AGE"),
#'   label = c("Study ID", "Unique Subject ID", "Age")
#' )
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID", "AGE"),
#'   sdtm_domain = "DM",   sdtm_var = c("STUDYID", "USUBJID", "AGE")
#' )
#' tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
#' tm$nodes
#' tm$edges
#'
#' @export
build_trace_model <- function(adam_meta,
                              sdtm_meta,
                              mapping = NULL,
                              spec    = NULL,
                              config  = trace_config_default()) {
  # Validate inputs
  adam_meta <- validate_metadata(adam_meta, kind = "adam")
  sdtm_meta <- validate_metadata(sdtm_meta, kind = "sdtm")

  uc <- config$uppercase_datasets
  if (uc) {
    adam_meta$dataset <- stringr::str_to_upper(adam_meta$dataset)
    sdtm_meta$dataset <- stringr::str_to_upper(sdtm_meta$dataset)
  }

  # Build nodes ----------------------------------------------------------
  adam_nodes <- build_variable_nodes(adam_meta, role = "adam")
  sdtm_nodes <- build_variable_nodes(sdtm_meta, role = "sdtm")
  nodes <- dplyr::bind_rows(adam_nodes, sdtm_nodes)

  # Build edges + diagnostics from mapping -------------------------------
  edges <- tibble::tibble(
    from_id    = character(0),
    to_id      = character(0),
    edge_type  = character(0),
    confidence = numeric(0),
    source     = character(0)
  )
  orphans     <- tibble::tibble(adam_dataset = character(0), adam_var = character(0))
  ambiguities <- tibble::tibble(adam_dataset = character(0), adam_var = character(0),
                                n_candidates = integer(0))
  conflicts   <- tibble::tibble(adam_dataset = character(0), adam_var = character(0),
                                detail = character(0))


  if (!is.null(mapping)) {
    mapping <- validate_mapping(mapping, uppercase_datasets = uc)

    # Create edges for each mapping row
    map_edges <- build_mapping_edges(mapping, adam_nodes, sdtm_nodes)
    edges <- dplyr::bind_rows(edges, map_edges)

    # Identify orphans: ADaM vars with no mapping row
    adam_keys <- paste0(adam_meta$dataset, ".", adam_meta$variable)
    map_keys  <- paste0(mapping$adam_dataset, ".", mapping$adam_var)
    orphan_keys <- setdiff(adam_keys, map_keys)

    if (length(orphan_keys) > 0L) {
      parts <- strsplit(orphan_keys, ".", fixed = TRUE)
      orphans <- tibble::tibble(
        adam_dataset = vapply(parts, `[[`, character(1), 1L),
        adam_var     = vapply(parts, `[[`, character(1), 2L)
      )
    }

    # Identify ambiguities: ADaM vars mapped to >1 SDTM source
    map_key <- paste0(mapping$adam_dataset, "|", mapping$adam_var)
    map_tab <- as.data.frame(table(map_key), stringsAsFactors = FALSE)
    names(map_tab) <- c("key", "n_candidates")
    map_tab <- map_tab[map_tab$n_candidates > 1L, , drop = FALSE]

    if (nrow(map_tab) > 0L) {
      parts <- strsplit(map_tab$key, "|", fixed = TRUE)
      ambiguities <- tibble::tibble(
        adam_dataset  = vapply(parts, `[[`, character(1), 1L),
        adam_var      = vapply(parts, `[[`, character(1), 2L),
        n_candidates  = as.integer(map_tab$n_candidates)
      )
    }
    # ambiguities already set above
  } else {
    # No mapping: all ADaM vars are orphans
    orphans <- tibble::tibble(
      adam_dataset = adam_meta$dataset,
      adam_var     = adam_meta$variable
    )
  }

  diagnostics <- list(
    orphans     = orphans,
    ambiguities = ambiguities,
    conflicts   = conflicts
  )

  structure(
    list(
      nodes       = nodes,
      edges       = edges,
      diagnostics = diagnostics,
      config      = config
    ),
    class = "trace_model"
  )
}


#' Print Trace Model
#' @param x A `trace_model` object.
#' @param ... Ignored.
#' @export
print.trace_model <- function(x, ...) {
  n_adam <- sum(x$nodes$role == "adam" & x$nodes$node_type == "variable")
  n_sdtm <- sum(x$nodes$role == "sdtm" & x$nodes$node_type == "variable")
  n_edges <- nrow(x$edges)
  n_orphans <- nrow(x$diagnostics$orphans)
  n_ambig <- nrow(x$diagnostics$ambiguities)

  cli::cli_alert_info("Trace Model: {n_adam} ADaM vars, {n_sdtm} SDTM vars")
  cli::cli_alert_info("  Edges: {n_edges}, Orphans: {n_orphans}, Ambiguities: {n_ambig}")
  invisible(x)
}


# --- Internal helpers ---------------------------------------------------

#' Build variable nodes from metadata
#' @noRd
build_variable_nodes <- function(meta, role) {
  node_ids <- vapply(
    seq_len(nrow(meta)),
    function(i) r4subcore::hash_id(role, meta$dataset[i], meta$variable[i], prefix = "N"),
    character(1)
  )

  tibble::tibble(
    node_id   = node_ids,
    node_type = "variable",
    dataset   = meta$dataset,
    variable  = meta$variable,
    label     = if ("label" %in% names(meta)) meta$label else NA_character_,
    role      = role
  )
}


#' Build mapping edges from validated mapping
#' @noRd
build_mapping_edges <- function(mapping, adam_nodes, sdtm_nodes) {
  from_ids <- vapply(
    seq_len(nrow(mapping)),
    function(i) {
      r4subcore::hash_id("adam", mapping$adam_dataset[i], mapping$adam_var[i], prefix = "N")
    },
    character(1)
  )

  to_ids <- vapply(
    seq_len(nrow(mapping)),
    function(i) {
      r4subcore::hash_id("sdtm", mapping$sdtm_domain[i], mapping$sdtm_var[i], prefix = "N")
    },
    character(1)
  )

  tibble::tibble(
    from_id    = from_ids,
    to_id      = to_ids,
    edge_type  = "derived_from",
    confidence = ifelse(is.na(mapping$confidence), NA_real_, mapping$confidence),
    source     = "mapping"
  )
}
