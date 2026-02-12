#' Compute Trace Levels for ADaM Variables
#'
#' Assigns a traceability level (L0--L3) to each ADaM variable in the trace
#' model based on available mapping, derivation text, and confidence scores.
#'
#' @details
#' Trace levels:
#' - **L0**: No mapping and no derivation text.
#' - **L1**: Derivation text present but no SDTM mapping.
#' - **L2**: Mapping to SDTM variable/domain exists.
#' - **L3**: Mapping exists AND (confidence >= threshold OR derivation text
#'   present alongside mapping).
#'
#' @param trace_model A `trace_model` object from [build_trace_model()].
#'
#' @return A tibble with columns: `adam_dataset`, `adam_var`, `trace_level`,
#'   `has_mapping`, `has_derivation_text`, `n_candidates`, `max_confidence`.
#'
#' @examples
#' adam_meta <- data.frame(
#'   dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGE", "AGEGR1"),
#'   label = c("Study ID", "Unique Subject ID", "Age", "Age Group")
#' )
#' sdtm_meta <- data.frame(
#'   dataset = "DM", variable = c("STUDYID", "USUBJID", "AGE"),
#'   label = c("Study ID", "Unique Subject ID", "Age")
#' )
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID", "AGE"),
#'   sdtm_domain = "DM",   sdtm_var = c("STUDYID", "USUBJID", "AGE"),
#'   confidence = c(1.0, 1.0, 0.9)
#' )
#' tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
#' compute_trace_levels(tm)
#'
#' @export
compute_trace_levels <- function(trace_model) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }

  config  <- trace_model$config
  nodes   <- trace_model$nodes
  edges   <- trace_model$edges

  # Get ADaM variable nodes
  adam_vars <- dplyr::filter(nodes, .data$role == "adam", .data$node_type == "variable")

  if (nrow(adam_vars) == 0L) {
    return(tibble::tibble(
      adam_dataset        = character(0),
      adam_var            = character(0),
      trace_level         = integer(0),
      has_mapping         = logical(0),
      has_derivation_text = logical(0),
      n_candidates        = integer(0),
      max_confidence      = numeric(0)
    ))
  }

  # Gather mapping info per ADaM variable node
  # edges: from_id (adam node) -> to_id (sdtm node), edge_type "derived_from"
  mapping_edges <- dplyr::filter(edges, .data$edge_type == "derived_from")

  # Count candidates and max confidence per ADaM node
  if (nrow(mapping_edges) > 0L) {
    edge_stats <- mapping_edges |>
      dplyr::group_by(.data$from_id) |>
      dplyr::summarise(
        n_candidates   = dplyr::n(),
        max_confidence = suppressWarnings(max(.data$confidence, na.rm = TRUE)),
        .groups = "drop"
      )
    # Replace -Inf from max(na.rm=TRUE) on all-NA with NA
    edge_stats$max_confidence[is.infinite(edge_stats$max_confidence)] <- NA_real_
  } else {
    edge_stats <- tibble::tibble(
      from_id        = character(0),
      n_candidates   = integer(0),
      max_confidence = numeric(0)
    )
  }

  # Gather derivation text from mapping (if stored in edges or diagnostics)
  # For v0.1, derivation text comes from the original mapping which we

  # reconstruct by checking the mapping in the model's edges source info.
  # We'll look at whether each adam var has derivation text by checking
  # the mapping used to build the model. Since we don't store derivation_text
  # on edges, we derive it from the mapping if available. For now, we check
  # the diagnostics + edges for presence of a mapping.
  # In a fuller version, derivation_text would be stored as an edge attribute.

  # For v0.1, has_derivation_text is FALSE unless edge source includes it.
  # We mark this based on the label field (heuristic: non-NA label on adam node

  # can indicate spec documentation). More robust in v0.2.

  result <- adam_vars[, c("node_id", "dataset", "variable", "label")]
  names(result) <- c("node_id", "adam_dataset", "adam_var", "label")
  result <- dplyr::left_join(result, edge_stats, by = c("node_id" = "from_id"))

  result$n_candidates[is.na(result$n_candidates)] <- 0L
  result$has_mapping <- result$n_candidates > 0L

  # has_derivation_text: TRUE if the variable has a non-empty label

  # (proxy for derivation documentation in v0.1; mapping derivation_text
  # support comes in v0.2 with proper attribute propagation)
  result$has_derivation_text <- !is.na(result$label) & nchar(result$label) > 0L

  # Compute trace levels
  threshold <- config$confidence_threshold_L3

  result$trace_level <- vapply(seq_len(nrow(result)), function(i) {
    has_map <- result$has_mapping[i]
    has_deriv <- result$has_derivation_text[i]
    max_conf <- result$max_confidence[i]

    if (has_map) {
      # L3 if confidence >= threshold OR if derivation text also present
      conf_ok <- !is.na(max_conf) && max_conf >= threshold
      if (conf_ok || has_deriv) {
        return(3L)
      }
      return(2L)
    }

    if (has_deriv) {
      return(1L)
    }

    0L
  }, integer(1))

  result[, c("adam_dataset", "adam_var", "trace_level",
             "has_mapping", "has_derivation_text",
             "n_candidates", "max_confidence")]
}
