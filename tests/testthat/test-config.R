test_that("trace_config_default returns expected structure", {
  cfg <- trace_config_default()
  expect_s3_class(cfg, "trace_config")
  expect_named(cfg, c("severity_by_level", "result_by_level",
                       "confidence_threshold_L3", "uppercase_datasets"))
  expect_equal(cfg$confidence_threshold_L3, 0.8)
  expect_true(cfg$uppercase_datasets)
})

test_that("trace_config_default accepts overrides", {
  cfg <- trace_config_default(confidence_threshold_L3 = 0.5, uppercase_datasets = FALSE)
  expect_equal(cfg$confidence_threshold_L3, 0.5)
  expect_false(cfg$uppercase_datasets)
})

test_that("trace_config_default severity_by_level maps correctly", {
  cfg <- trace_config_default()
  expect_equal(unname(cfg$severity_by_level["L0"]), "high")
  expect_equal(unname(cfg$severity_by_level["L1"]), "medium")
  expect_equal(unname(cfg$severity_by_level["L2"]), "low")
  expect_equal(unname(cfg$severity_by_level["L3"]), "info")
})

test_that("trace_config_default result_by_level maps correctly", {
  cfg <- trace_config_default()
  expect_equal(unname(cfg$result_by_level["L0"]), "fail")
  expect_equal(unname(cfg$result_by_level["L1"]), "warn")
  expect_equal(unname(cfg$result_by_level["L3"]), "pass")
})

test_that("trace_config_default rejects invalid inputs", {
  expect_error(trace_config_default(confidence_threshold_L3 = "high"))
  expect_error(trace_config_default(uppercase_datasets = "yes"))
})
