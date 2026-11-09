# Tests for the impact report (R/trace_impact_report.R)

mk_impact_model <- function() {
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

impact_deriv <- data.frame(
  from_dataset = c("ADAE", "ADTTE"),
  from_var     = c("AAGE", "TAGE"),
  to_dataset   = c("ADSL", "ADAE"),
  to_var       = c("AGE", "AAGE"),
  stringsAsFactors = FALSE
)

test_that("summarize_impact rolls up by dataset and by level", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = impact_deriv)

  roll <- suppressMessages(summarize_impact(imp))
  expect_named(roll, c("by_dataset", "by_level"))

  expect_setequal(roll$by_dataset$dataset, c("ADSL", "ADAE", "ADTTE"))
  expect_true(all(roll$by_dataset$n_impacted == 1L))

  expect_equal(roll$by_level$depth, c(1L, 2L, 3L))
  expect_true(all(roll$by_level$n_impacted == 1L))
  expect_equal(sum(roll$by_level$n_impacted), nrow(imp))
})

test_that("summarize_impact prints an overview", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = impact_deriv)
  expect_message(summarize_impact(imp), "downstream variable")
})

test_that("summarize_impact handles an empty impact result", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "ADTTE.TAGE", adam_derivations = impact_deriv)
  expect_equal(nrow(imp), 0L)

  roll <- suppressMessages(summarize_impact(imp))
  expect_equal(nrow(roll$by_dataset), 0L)
  expect_equal(nrow(roll$by_level), 0L)
})

test_that("export_impact_report returns a data.frame with a changed column", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = impact_deriv)

  report <- export_impact_report(imp)
  expect_s3_class(report, "tbl_df")
  expect_equal(report$changed, rep("DM.AGE", nrow(imp)))
  expect_true(all(c("changed", "dataset", "variable", "role", "depth", "path")
                  %in% names(report)))
  expect_equal(nrow(report), nrow(imp))
})

test_that("csv export writes a file and returns the path", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = impact_deriv)

  path <- tempfile(fileext = ".csv")
  out <- suppressMessages(export_impact_report(imp, format = "csv", path = path))
  expect_equal(out, path)
  expect_true(file.exists(path))

  back <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_true("DM.AGE" %in% back$changed)
  expect_equal(nrow(back), nrow(imp))
  unlink(path)
})

test_that("xlsx export writes a file", {
  skip_if_not_installed("writexl")
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = impact_deriv)

  path <- tempfile(fileext = ".xlsx")
  suppressMessages(export_impact_report(imp, format = "xlsx", path = path))
  expect_true(file.exists(path))
  unlink(path)
})

test_that("csv and xlsx formats require a path", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "DM.AGE", adam_derivations = impact_deriv)
  expect_error(export_impact_report(imp, format = "csv"), "path")
  expect_error(export_impact_report(imp, format = "xlsx"), "path")
})

test_that("an empty impact result still exports", {
  tm <- mk_impact_model()
  imp <- trace_impact(tm, "ADTTE.TAGE", adam_derivations = impact_deriv)

  report <- export_impact_report(imp)
  expect_equal(nrow(report), 0L)
  expect_true("changed" %in% names(report))
})

test_that("inputs are validated", {
  expect_error(summarize_impact(list()), "trace_impact")
  expect_error(export_impact_report(data.frame(x = 1)), "trace_impact")
})
