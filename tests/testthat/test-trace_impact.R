# Tests for trace_impact() (R/trace_impact.R)

mk_model <- function() {
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

deriv <- data.frame(
  from_dataset = c("ADAE", "ADTTE"),
  from_var     = c("AAGE", "TAGE"),
  to_dataset   = c("ADSL", "ADAE"),
  to_var       = c("AGE", "AAGE"),
  stringsAsFactors = FALSE
)

test_that("impact of a source variable reaches the whole chain", {
  tm <- mk_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv)

  expect_s3_class(imp, "tbl_df")
  expect_setequal(paste0(imp$dataset, ".", imp$variable),
                  c("ADSL.AGE", "ADAE.AAGE", "ADTTE.TAGE"))
  expect_equal(imp$depth[paste0(imp$dataset, ".", imp$variable) == "ADSL.AGE"], 1L)
  expect_equal(imp$depth[paste0(imp$dataset, ".", imp$variable) == "ADAE.AAGE"], 2L)
  expect_equal(imp$depth[paste0(imp$dataset, ".", imp$variable) == "ADTTE.TAGE"], 3L)
  expect_equal(attr(imp, "changed"), "DM.AGE")
})

test_that("impact of a mid-chain variable reaches only what is downstream", {
  tm <- mk_model()
  imp <- trace_impact(tm, "ADSL.AGE", adam_derivations = deriv)
  expect_setequal(paste0(imp$dataset, ".", imp$variable),
                  c("ADAE.AAGE", "ADTTE.TAGE"))
  expect_false("ADSL.AGE" %in% paste0(imp$dataset, ".", imp$variable))
})

test_that("a leaf variable impacts nothing", {
  tm <- mk_model()
  imp <- trace_impact(tm, "ADTTE.TAGE", adam_derivations = deriv)
  expect_equal(nrow(imp), 0L)
  expect_true(all(c("dataset", "variable", "role", "depth", "path") %in% names(imp)))
})

test_that("path reads from the impacted variable back to the change", {
  tm <- mk_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv)
  p <- imp$path[paste0(imp$dataset, ".", imp$variable) == "ADTTE.TAGE"]
  expect_equal(p, "ADTTE.TAGE -> ADAE.AAGE -> ADSL.AGE -> DM.AGE")
})

test_that("max_depth limits how far impact is reported", {
  tm <- mk_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = deriv, max_depth = 1)
  expect_equal(paste0(imp$dataset, ".", imp$variable), "ADSL.AGE")
})

test_that("without ADaM derivations, only the direct mapping is followed", {
  tm <- mk_model()
  imp <- trace_impact(tm, "DM.AGE")
  expect_equal(paste0(imp$dataset, ".", imp$variable), "ADSL.AGE")
})

test_that("an unknown variable is an informative error", {
  tm <- mk_model()
  expect_error(trace_impact(tm, "DM.NOPE"), "not in the trace model")
  expect_error(trace_impact(tm, c("A.B", "C.D")), "single")
})

test_that("circular derivations do not loop", {
  tm <- mk_model()
  cyc <- data.frame(
    from_dataset = c("ADAE", "ADSL"),
    from_var     = c("AAGE", "AGE"),
    to_dataset   = c("ADSL", "ADAE"),
    to_var       = c("AGE", "AAGE"),
    stringsAsFactors = FALSE
  )
  # ADSL.AGE derives from ADAE.AAGE and vice versa
  imp <- trace_impact(tm, "ADSL.AGE", adam_derivations = cyc)
  expect_true("ADAE.AAGE" %in% paste0(imp$dataset, ".", imp$variable))
  expect_false("ADSL.AGE" %in% paste0(imp$dataset, ".", imp$variable))
})
