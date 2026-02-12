#' Validate Dataset Metadata
#'
#' Checks that an ADaM or SDTM metadata data.frame contains the required
#' columns (`dataset`, `variable`) and canonicalizes column names to lowercase.
#'
#' @param df A data.frame of dataset metadata.
#' @param kind Character; `"adam"` or `"sdtm"`. Used in error messages only.
#'
#' @return A tibble with canonicalized column names.
#'
#' @examples
#' meta <- data.frame(DATASET = "ADSL", VARIABLE = "SUBJID", LABEL = "Subject ID")
#' validate_metadata(meta, kind = "adam")
#'
#' @export
validate_metadata <- function(df, kind = c("adam", "sdtm")) {
  kind <- rlang::arg_match(kind)

  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data.frame, not {.cls {class(df)}}.")
  }

  # Canonicalize column names: lowercase, trim whitespace
  names(df) <- stringr::str_trim(tolower(names(df)))

  required <- c("dataset", "variable")
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "{kind} metadata is missing required column(s): {.val {missing_cols}}."
    )
  }

  # Ensure expected optional columns exist (fill with NA if missing)
  optional <- c("label", "type", "length", "format")
  nr <- nrow(df)
  for (col in optional) {
    if (!col %in% names(df)) {
      df[[col]] <- rep(NA_character_, nr)
    }
  }

  # Coerce key columns to character and trim
  df$dataset  <- stringr::str_trim(as.character(df$dataset))
  df$variable <- stringr::str_trim(as.character(df$variable))

  tibble::as_tibble(df)
}


#' Validate Trace Mapping
#'
#' Checks that a mapping data.frame contains the required columns
#' (`adam_dataset`, `adam_var`, `sdtm_domain`, `sdtm_var`) and canonicalizes
#' names, trims whitespace, and optionally uppercases dataset/domain names.
#'
#' @param df A data.frame describing ADaM-to-SDTM variable mappings.
#' @param uppercase_datasets Logical; if `TRUE`, uppercases `adam_dataset`
#'   and `sdtm_domain`. Default `TRUE`.
#'
#' @return A tibble with canonicalized column names and values.
#'
#' @examples
#' map <- data.frame(
#'   ADAM_DATASET = "adsl", ADAM_VAR = "AGE",
#'   SDTM_DOMAIN = "dm", SDTM_VAR = "AGE"
#' )
#' validate_mapping(map)
#'
#' @export
validate_mapping <- function(df, uppercase_datasets = TRUE) {
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data.frame, not {.cls {class(df)}}.")
  }

  # Canonicalize column names: lowercase, trim, replace spaces/dots with _
  nms <- tolower(stringr::str_trim(names(df)))
  nms <- gsub("[. ]+", "_", nms)
  names(df) <- nms

  required <- c("adam_dataset", "adam_var", "sdtm_domain", "sdtm_var")
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "Mapping is missing required column(s): {.val {missing_cols}}."
    )
  }

  # Ensure optional columns
  if (!"derivation_text" %in% names(df)) df$derivation_text <- NA_character_
  if (!"confidence" %in% names(df)) df$confidence <- NA_real_

  # Coerce and trim
  for (col in required) {
    df[[col]] <- stringr::str_trim(as.character(df[[col]]))
  }
  df$derivation_text <- as.character(df$derivation_text)
  df$confidence      <- as.numeric(df$confidence)

  # Uppercase dataset/domain names

  if (uppercase_datasets) {
    df$adam_dataset <- stringr::str_to_upper(df$adam_dataset)
    df$sdtm_domain <- stringr::str_to_upper(df$sdtm_domain)
  }

  tibble::as_tibble(df)
}
