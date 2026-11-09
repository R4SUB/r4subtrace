# Tests for sdtm_utilization() (R/trace_utilization.R)

mk_model <- function() {
  adam <- data.frame(
    dataset  = c("ADSL", "ADSL"),
    variable = c("AGE", "SEX"),
    label    = c("Age", "Sex"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(
    dataset  = c("DM", "DM", "VS"),
    variable = c("AGE", "SEX", "VSSTRESN"),
    label    = c("Age", "Sex", "Result"),
    stringsAsFactors = FALSE
  )
  map <- data.frame(
    adam_dataset = c("ADSL", "ADSL"),
    adam_var     = c("AGE", "SEX"),
    sdtm_domain  = c("DM", "DM"),
    sdtm_var     = c("AGE", "SEX"),
    confidence   = 1,
    stringsAsFactors = FALSE
  )
  suppressMessages(build_trace_model(adam, sdtm, mapping = map))
}

test_that("unused SDTM sources are flagged and referenced ones are not", {
  tm <- mk_model()
  util <- sdtm_utilization(tm)

  expect_s3_class(util, "tbl_df")
  expect_setequal(names(util), c("dataset", "variable", "used_count", "referenced"))
  expect_equal(nrow(util), 3L)

  key <- paste0(util$dataset, ".", util$variable)
  expect_false(util$referenced[key == "VS.VSSTRESN"])
  expect_true(util$referenced[key == "DM.AGE"])
  expect_true(util$referenced[key == "DM.SEX"])
})

test_that("used_count counts referencing ADaM variables", {
  tm <- mk_model()
  util <- sdtm_utilization(tm)
  key <- paste0(util$dataset, ".", util$variable)

  expect_equal(util$used_count[key == "DM.AGE"], 1L)
  expect_equal(util$used_count[key == "VS.VSSTRESN"], 0L)
  expect_true(is.integer(util$used_count))
})

test_that("unused sources are listed first", {
  tm <- mk_model()
  util <- sdtm_utilization(tm)
  expect_false(util$referenced[1])
  expect_equal(paste0(util$dataset[1], ".", util$variable[1]), "VS.VSSTRESN")
})

test_that("multiple ADaM variables mapping to one source raise its count", {
  adam <- data.frame(
    dataset  = c("ADSL", "ADAE"),
    variable = c("AGE", "AAGE"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(dataset = "DM", variable = "AGE", stringsAsFactors = FALSE)
  map <- data.frame(
    adam_dataset = c("ADSL", "ADAE"),
    adam_var     = c("AGE", "AAGE"),
    sdtm_domain  = "DM",
    sdtm_var     = "AGE",
    confidence   = 1,
    stringsAsFactors = FALSE
  )
  tm <- suppressMessages(build_trace_model(adam, sdtm, mapping = map))
  util <- sdtm_utilization(tm)

  expect_equal(util$used_count[util$variable == "AGE"], 2L)
  expect_true(util$referenced[util$variable == "AGE"])
})

test_that("ADaM derivations do not change SDTM utilization", {
  tm <- mk_model()
  deriv <- data.frame(
    from_dataset = "ADAE", from_var = "AAGE",
    to_dataset   = "ADSL", to_var  = "AGE",
    stringsAsFactors = FALSE
  )
  a <- sdtm_utilization(tm)
  b <- sdtm_utilization(tm, adam_derivations = deriv)
  expect_equal(a, b)
})

test_that("a model with no mapping marks every SDTM source unused", {
  adam <- data.frame(dataset = "ADSL", variable = "AGE", stringsAsFactors = FALSE)
  sdtm <- data.frame(
    dataset = "DM", variable = c("AGE", "SEX"), stringsAsFactors = FALSE
  )
  tm <- suppressMessages(build_trace_model(adam, sdtm))
  util <- sdtm_utilization(tm)

  expect_equal(nrow(util), 2L)
  expect_false(any(util$referenced))
  expect_true(all(util$used_count == 0L))
})

test_that("a non-model input is an informative error", {
  expect_error(sdtm_utilization(list()), "trace_model")
})

test_that("a model with no SDTM variables returns zero rows", {
  adam <- data.frame(dataset = "ADSL", variable = "AGE", stringsAsFactors = FALSE)
  sdtm <- data.frame(
    dataset = character(0), variable = character(0), stringsAsFactors = FALSE
  )
  tm <- suppressMessages(build_trace_model(adam, sdtm))
  util <- sdtm_utilization(tm)
  expect_equal(nrow(util), 0L)
  expect_setequal(names(util), c("dataset", "variable", "used_count", "referenced"))
})
