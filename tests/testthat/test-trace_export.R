# Tests for the traceability coverage export (R/trace_export.R)

make_trace_model <- function() {
  adam_meta <- data.frame(
    dataset = "ADSL",
    variable = c("STUDYID", "USUBJID", "AGE", "AGEGR1"),
    label = c("Study ID", "Unique Subject ID", "Age", NA)
  )
  sdtm_meta <- data.frame(
    dataset = "DM",
    variable = c("STUDYID", "USUBJID", "AGE"),
    label = c("Study ID", "Unique Subject ID", "Age")
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = c("STUDYID", "USUBJID", "AGE"),
    sdtm_domain = "DM", sdtm_var = c("STUDYID", "USUBJID", "AGE"),
    confidence = c(1, 1, 0.9)
  )
  build_trace_model(adam_meta, sdtm_meta, mapping = map)
}

test_that("coverage reports one row per dataset with correct counts", {
  tm <- make_trace_model()
  cov <- traceability_coverage(tm)

  expect_equal(nrow(cov), 1L)
  expect_equal(cov$adam_dataset, "ADSL")
  expect_equal(cov$n_variables, 4L)
  # Three variables are mapped (traced), AGEGR1 is not.
  expect_equal(cov$n_traced, 3L)
  expect_equal(cov$n_untraced, 1L)
  expect_equal(cov$pct_traced, 75)
  expect_match(cov$untraced_vars, "AGEGR1")
})

test_that("traced_min_level controls what counts as traced", {
  tm <- make_trace_model()
  strict <- traceability_coverage(tm, traced_min_level = 3L)
  loose  <- traceability_coverage(tm, traced_min_level = 2L)

  expect_gte(loose$n_traced, strict$n_traced)
})

test_that("the report appends an overall summary row", {
  tm <- make_trace_model()
  report <- export_traceability_report(tm)

  expect_true("OVERALL" %in% report$adam_dataset)
  overall <- report[report$adam_dataset == "OVERALL", ]
  expect_equal(overall$n_variables, sum(report$n_variables[report$adam_dataset != "OVERALL"]))
  expect_equal(overall$n_traced, 3L)
})

test_that("csv export writes a file and returns the path", {
  tm <- make_trace_model()
  path <- tempfile(fileext = ".csv")
  out <- export_traceability_report(tm, format = "csv", path = path)

  expect_equal(out, path)
  expect_true(file.exists(path))
  back <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_true("OVERALL" %in% back$adam_dataset)
  unlink(path)
})

test_that("xlsx export writes a file", {
  skip_if_not_installed("writexl")
  tm <- make_trace_model()
  path <- tempfile(fileext = ".xlsx")
  export_traceability_report(tm, format = "xlsx", path = path)
  expect_true(file.exists(path))
  unlink(path)
})

test_that("csv and xlsx formats require a path", {
  tm <- make_trace_model()
  expect_error(export_traceability_report(tm, format = "csv"), "path")
  expect_error(export_traceability_report(tm, format = "xlsx"), "path")
})

test_that("inputs are validated", {
  expect_error(traceability_coverage(list()), "trace_model")
  tm <- make_trace_model()
  expect_error(traceability_coverage(tm, traced_min_level = 9), "0:3")
})
