#' Convert Trace Model to R4SUB Evidence
#'
#' Emits evidence rows compatible with `r4subcore::validate_evidence()` for
#' each ADaM variable's trace level, plus diagnostic rows for orphans,
#' ambiguities, and conflicts.
#'
#' @param trace_model A `trace_model` object from [build_trace_model()].
#' @param ctx An `r4sub_run_context` from `r4subcore::r4sub_run_context()`.
#' @param source_name Character; the name of the evidence source.
#' @param source_version Character or `NULL`; version of the source.
#'
#' @return A data.frame of evidence rows passing `r4subcore::validate_evidence()`.
#'
#' @examples
#' library(r4subcore)
#' ctx <- r4sub_run_context(study_id = "TEST001", environment = "DEV")
#' adam_meta <- data.frame(
#'   dataset = "ADSL", variable = c("STUDYID", "AGE"),
#'   label = c("Study ID", "Age")
#' )
#' sdtm_meta <- data.frame(
#'   dataset = "DM", variable = c("STUDYID", "AGE"),
#'   label = c("Study ID", "Age")
#' )
#' map <- data.frame(
#'   adam_dataset = "ADSL", adam_var = c("STUDYID", "AGE"),
#'   sdtm_domain = "DM",   sdtm_var = c("STUDYID", "AGE")
#' )
#' tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
#' ev <- trace_model_to_evidence(tm, ctx = ctx)
#' r4subcore::validate_evidence(ev)
#'
#' @export
trace_model_to_evidence <- function(trace_model,
                                    ctx,
                                    source_name    = "r4subtrace",
                                    source_version = NULL) {
  if (!inherits(trace_model, "trace_model")) {
    cli::cli_abort("{.arg trace_model} must be a {.cls trace_model} object.")
  }

  config <- trace_model$config
  levels <- compute_trace_levels(trace_model)
  diag   <- trace_model$diagnostics

  evidence_rows <- list()

  # A) Per-variable trace level evidence ---------------------------------
  if (nrow(levels) > 0L) {
    sev_map <- config$severity_by_level
    res_map <- config$result_by_level

    level_labels <- paste0("L", levels$trace_level)
    severities <- unname(sev_map[level_labels])
    results    <- unname(res_map[level_labels])

    # Build payload for each row
    payloads <- vapply(seq_len(nrow(levels)), function(i) {
      r4subcore::json_safely(list(
        trace_level         = levels$trace_level[i],
        has_mapping         = levels$has_mapping[i],
        has_derivation_text = levels$has_derivation_text[i],
        n_candidates        = levels$n_candidates[i],
        max_confidence      = levels$max_confidence[i]
      ))
    }, character(1))

    var_evidence <- data.frame(
      asset_type       = "dataset",
      asset_id         = levels$adam_dataset,
      source_name      = source_name,
      source_version   = source_version %||% NA_character_,
      indicator_id     = "TRACE_LEVEL",
      indicator_name   = "Traceability level for ADaM variable",
      indicator_domain = "trace",
      severity         = severities,
      result           = results,
      metric_value     = as.numeric(levels$trace_level),
      metric_unit      = "level",
      message          = paste0(
        levels$adam_dataset, ".", levels$adam_var,
        " trace level: L", levels$trace_level
      ),
      location         = paste0(levels$adam_dataset, ":", levels$adam_var),
      evidence_payload = payloads,
      stringsAsFactors = FALSE
    )
    evidence_rows <- c(evidence_rows, list(var_evidence))
  }

  # B) Diagnostic: Orphans -----------------------------------------------
  if (nrow(diag$orphans) > 0L) {
    orphan_ev <- data.frame(
      asset_type       = "dataset",
      asset_id         = diag$orphans$adam_dataset,
      source_name      = source_name,
      source_version   = source_version %||% NA_character_,
      indicator_id     = "TRACE_ORPHAN_VAR",
      indicator_name   = "Orphan ADaM variable with no SDTM mapping",
      indicator_domain = "trace",
      severity         = "high",
      result           = "fail",
      metric_value     = NA_real_,
      metric_unit      = NA_character_,
      message          = paste0(
        diag$orphans$adam_dataset, ".", diag$orphans$adam_var,
        " has no SDTM mapping"
      ),
      location         = paste0(diag$orphans$adam_dataset, ":", diag$orphans$adam_var),
      evidence_payload = "{}",
      stringsAsFactors = FALSE
    )
    evidence_rows <- c(evidence_rows, list(orphan_ev))
  }

  # C) Diagnostic: Ambiguities -------------------------------------------
  if (nrow(diag$ambiguities) > 0L) {
    ambig_ev <- data.frame(
      asset_type       = "dataset",
      asset_id         = diag$ambiguities$adam_dataset,
      source_name      = source_name,
      source_version   = source_version %||% NA_character_,
      indicator_id     = "TRACE_AMBIGUOUS_MAPPING",
      indicator_name   = "Ambiguous mapping: ADaM variable maps to multiple SDTM sources",
      indicator_domain = "trace",
      severity         = "medium",
      result           = "warn",
      metric_value     = as.numeric(diag$ambiguities$n_candidates),
      metric_unit      = "candidates",
      message          = paste0(
        diag$ambiguities$adam_dataset, ".", diag$ambiguities$adam_var,
        " has ", diag$ambiguities$n_candidates, " SDTM mapping candidates"
      ),
      location         = paste0(
        diag$ambiguities$adam_dataset, ":", diag$ambiguities$adam_var
      ),
      evidence_payload = "{}",
      stringsAsFactors = FALSE
    )
    evidence_rows <- c(evidence_rows, list(ambig_ev))
  }

  # D) Diagnostic: Conflicts ---------------------------------------------
  if (nrow(diag$conflicts) > 0L) {
    conflict_ev <- data.frame(
      asset_type       = "dataset",
      asset_id         = diag$conflicts$adam_dataset,
      source_name      = source_name,
      source_version   = source_version %||% NA_character_,
      indicator_id     = "TRACE_CONFLICT",
      indicator_name   = "Spec vs mapping conflict",
      indicator_domain = "trace",
      severity         = "high",
      result           = "fail",
      metric_value     = NA_real_,
      metric_unit      = NA_character_,
      message          = diag$conflicts$detail,
      location         = paste0(
        diag$conflicts$adam_dataset, ":", diag$conflicts$adam_var
      ),
      evidence_payload = "{}",
      stringsAsFactors = FALSE
    )
    evidence_rows <- c(evidence_rows, list(conflict_ev))
  }

  # Combine all evidence rows
  if (length(evidence_rows) == 0L) {
    cli::cli_alert_warning("No evidence rows generated from trace model.")
    # Return an empty but valid evidence frame
    ev <- empty_evidence(source_name, source_version)
    return(r4subcore::as_evidence(ev, ctx = ctx))
  }

  ev <- do.call(rbind, evidence_rows)
  r4subcore::as_evidence(ev, ctx = ctx)
}


#' Create an empty evidence data.frame with correct columns
#' @noRd
empty_evidence <- function(source_name = "r4subtrace", source_version = NULL) {
  data.frame(
    asset_type       = character(0),
    asset_id         = character(0),
    source_name      = character(0),
    source_version   = character(0),
    indicator_id     = character(0),
    indicator_name   = character(0),
    indicator_domain = character(0),
    severity         = character(0),
    result           = character(0),
    metric_value     = numeric(0),
    metric_unit      = character(0),
    message          = character(0),
    location         = character(0),
    evidence_payload = character(0),
    stringsAsFactors = FALSE
  )
}
