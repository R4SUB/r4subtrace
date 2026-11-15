# Tests for validate_trace_graph() and trace_lineage() (R/trace_validate.R)

# Base model: ADSL.AGE maps to DM.AGE; ADSL.ORPH and DM.UNUSED touch nothing;
# ADAE.AAGE is only reached through adam_derivations.
mk_model <- function() {
  adam <- data.frame(
    dataset  = c("ADSL", "ADSL", "ADAE"),
    variable = c("AGE", "ORPH", "AAGE"),
    label    = c("Age", "Orphan", "Analysis Age"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(
    dataset  = c("DM", "DM"),
    variable = c("AGE", "UNUSED"),
    label    = c("Age", "Unused"),
    stringsAsFactors = FALSE
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  suppressMessages(build_trace_model(adam, sdtm, mapping = map))
}

key <- function(df) paste(df$check, df$dataset, df$variable, sep = ".")

# --- validate_trace_graph() ---------------------------------------------

test_that("input is validated", {
  expect_error(validate_trace_graph(list()), "trace_model")
})

test_that("isolated nodes are reported as orphans", {
  tm <- mk_model()
  v <- validate_trace_graph(tm)

  expect_s3_class(v, "tbl_df")
  expect_true(all(c("check", "dataset", "variable", "role", "detail") %in% names(v)))
  # ADSL.AGE and DM.AGE take part in the mapping edge; the rest are isolated.
  orph <- v[v$check == "orphan", ]
  expect_setequal(paste0(orph$dataset, ".", orph$variable),
                  c("ADSL.ORPH", "ADAE.AAGE", "DM.UNUSED"))
  expect_equal(nrow(v), 3L)
  expect_false(any(v$check == "cycle"))
})

test_that("a supplied derivation removes an orphan", {
  tm <- mk_model()
  deriv <- data.frame(
    from_dataset = "ADAE", from_var = "AAGE",
    to_dataset = "ADSL", to_var = "AGE", stringsAsFactors = FALSE
  )
  v <- validate_trace_graph(tm, adam_derivations = deriv)
  orph <- v[v$check == "orphan", ]
  expect_setequal(paste0(orph$dataset, ".", orph$variable),
                  c("ADSL.ORPH", "DM.UNUSED"))
  expect_false("ADAE.AAGE" %in% paste0(orph$dataset, ".", orph$variable))
})

test_that("a circular derivation is detected and both nodes are flagged", {
  tm <- mk_model()
  cyc <- data.frame(
    from_dataset = c("ADSL", "ADAE"), from_var = c("AGE", "AAGE"),
    to_dataset   = c("ADAE", "ADSL"), to_var   = c("AAGE", "AGE"),
    stringsAsFactors = FALSE
  )
  v <- validate_trace_graph(tm, adam_derivations = cyc)
  cyc_rows <- v[v$check == "cycle", ]
  expect_setequal(paste0(cyc_rows$dataset, ".", cyc_rows$variable),
                  c("ADSL.AGE", "ADAE.AAGE"))
  expect_match(cyc_rows$detail[1], "circular")
})

test_that("a self-derivation is detected", {
  tm <- mk_model()
  slf <- data.frame(
    from_dataset = "ADAE", from_var = "AAGE",
    to_dataset = "ADAE", to_var = "AAGE", stringsAsFactors = FALSE
  )
  v <- validate_trace_graph(tm, adam_derivations = slf)
  cyc_rows <- v[v$check == "cycle", ]
  expect_equal(paste0(cyc_rows$dataset, ".", cyc_rows$variable), "ADAE.AAGE")
  expect_match(cyc_rows$detail, "itself")
})

test_that("an edge to a non-existent node is a dangling edge", {
  tm <- mk_model()
  bad <- data.frame(
    from_dataset = "ADAE", from_var = "AAGE",
    to_dataset = "ADSL", to_var = "NOPE", stringsAsFactors = FALSE
  )
  v <- validate_trace_graph(tm, adam_derivations = bad)
  dang <- v[v$check == "dangling_edge", ]
  expect_equal(paste0(dang$dataset, ".", dang$variable), "ADSL.NOPE")
  expect_equal(dang$role, "adam")
})

test_that("a component with no SDTM source is disconnected", {
  adam <- data.frame(
    dataset  = c("ADSL", "ADX", "ADX"),
    variable = c("AGE", "A", "B"),
    label    = c("Age", "A", "B"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age",
                     stringsAsFactors = FALSE)
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  tm <- suppressMessages(build_trace_model(adam, sdtm, mapping = map))
  # ADX.A derives from ADX.B; neither touches SDTM.
  deriv <- data.frame(
    from_dataset = "ADX", from_var = "A",
    to_dataset = "ADX", to_var = "B", stringsAsFactors = FALSE
  )
  v <- validate_trace_graph(tm, adam_derivations = deriv)
  disc <- v[v$check == "disconnected", ]
  expect_setequal(paste0(disc$dataset, ".", disc$variable),
                  c("ADX.A", "ADX.B"))
  # The grounded ADSL.AGE -> DM.AGE component is not flagged.
  expect_false("ADSL.AGE" %in% paste0(disc$dataset, ".", disc$variable))
  expect_false(any(v$check == "orphan"))
})

test_that("a fully grounded, mapping-only model with no orphans is clean", {
  adam <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age",
                     stringsAsFactors = FALSE)
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age",
                     stringsAsFactors = FALSE)
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  tm <- suppressMessages(build_trace_model(adam, sdtm, mapping = map))
  v <- validate_trace_graph(tm)
  expect_equal(nrow(v), 0L)
  expect_true(all(c("check", "dataset", "variable", "role", "detail") %in% names(v)))
})

# --- trace_lineage() ----------------------------------------------------

mk_chain_model <- function() {
  adam <- data.frame(
    dataset = c("ADSL", "ADAE", "ADTTE"),
    variable = c("AGE", "AAGE", "TAGE"),
    label = c("Age", "Analysis Age", "Time Age"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age",
                     stringsAsFactors = FALSE)
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  suppressMessages(build_trace_model(adam, sdtm, mapping = map))
}

chain_deriv <- data.frame(
  from_dataset = c("ADAE", "ADTTE"),
  from_var     = c("AAGE", "TAGE"),
  to_dataset   = c("ADSL", "ADAE"),
  to_var       = c("AGE", "AAGE"),
  stringsAsFactors = FALSE
)

test_that("upstream lineage returns the full ancestry down to SDTM", {
  tm <- mk_chain_model()
  up <- trace_lineage(tm, "ADTTE.TAGE", "upstream", adam_derivations = chain_deriv)

  expect_s3_class(up, "tbl_df")
  expect_setequal(paste0(up$dataset, ".", up$variable),
                  c("ADAE.AAGE", "ADSL.AGE", "DM.AGE"))
  expect_equal(up$depth[paste0(up$dataset, ".", up$variable) == "ADAE.AAGE"], 1L)
  expect_equal(up$depth[paste0(up$dataset, ".", up$variable) == "DM.AGE"], 3L)
  expect_equal(attr(up, "node"), "ADTTE.TAGE")
  expect_equal(attr(up, "direction"), "upstream")
})

test_that("upstream path reads outward from the queried node", {
  tm <- mk_chain_model()
  up <- trace_lineage(tm, "ADTTE.TAGE", "upstream", adam_derivations = chain_deriv)
  p <- up$path[paste0(up$dataset, ".", up$variable) == "DM.AGE"]
  expect_equal(p, "ADTTE.TAGE -> ADAE.AAGE -> ADSL.AGE -> DM.AGE")
})

test_that("downstream lineage returns dependents nearest first", {
  tm <- mk_chain_model()
  down <- trace_lineage(tm, "DM.AGE", "downstream", adam_derivations = chain_deriv)
  expect_setequal(paste0(down$dataset, ".", down$variable),
                  c("ADSL.AGE", "ADAE.AAGE", "ADTTE.TAGE"))
  expect_equal(down$depth[paste0(down$dataset, ".", down$variable) == "ADSL.AGE"], 1L)
  expect_equal(down$depth[paste0(down$dataset, ".", down$variable) == "ADTTE.TAGE"], 3L)
})

test_that("a leaf has no upstream and a root has no downstream", {
  tm <- mk_chain_model()
  up <- trace_lineage(tm, "DM.AGE", "upstream", adam_derivations = chain_deriv)
  expect_equal(nrow(up), 0L)
  expect_equal(attr(up, "direction"), "upstream")
  expect_true(all(c("dataset", "variable", "role", "depth", "path") %in% names(up)))
})

test_that("max_depth limits the reported lineage", {
  tm <- mk_chain_model()
  up <- trace_lineage(tm, "ADTTE.TAGE", "upstream",
                      adam_derivations = chain_deriv, max_depth = 1)
  expect_equal(paste0(up$dataset, ".", up$variable), "ADAE.AAGE")
})

test_that("direction defaults to upstream", {
  tm <- mk_chain_model()
  up <- trace_lineage(tm, "ADAE.AAGE", adam_derivations = chain_deriv)
  expect_equal(attr(up, "direction"), "upstream")
  expect_setequal(paste0(up$dataset, ".", up$variable),
                  c("ADSL.AGE", "DM.AGE"))
})

test_that("circular lineage does not loop", {
  tm <- mk_chain_model()
  cyc <- data.frame(
    from_dataset = c("ADAE", "ADSL"), from_var = c("AAGE", "AGE"),
    to_dataset   = c("ADSL", "ADAE"), to_var   = c("AGE", "AAGE"),
    stringsAsFactors = FALSE
  )
  up <- trace_lineage(tm, "ADSL.AGE", "upstream", adam_derivations = cyc)
  expect_true("ADAE.AAGE" %in% paste0(up$dataset, ".", up$variable))
  expect_false("ADSL.AGE" %in% paste0(up$dataset, ".", up$variable))
})

test_that("errors are informative", {
  tm <- mk_chain_model()
  expect_error(trace_lineage(tm, "DM.NOPE"), "not in the trace model")
  expect_error(trace_lineage(tm, c("A.B", "C.D")), "single")
  expect_error(trace_lineage(tm, "DM.AGE", direction = "sideways"))
  expect_error(trace_lineage(list(), "DM.AGE"), "trace_model")
})
