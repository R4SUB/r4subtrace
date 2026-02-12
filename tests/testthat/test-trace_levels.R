test_that("compute_trace_levels returns L2/L3 for mapped vars", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = c("STUDYID", "AGE"),
    label = c("Study ID", "Age")
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = c("STUDYID", "AGE"),
    label = c("Study ID", "Age")
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = c("STUDYID", "AGE"),
    sdtm_domain = "DM", sdtm_var = c("STUDYID", "AGE"),
    confidence = c(0.9, 0.9)
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  levels <- compute_trace_levels(tm)

  expect_equal(nrow(levels), 2)
  # Both have mapping + label -> L3

  expect_true(all(levels$trace_level == 3L))
  expect_true(all(levels$has_mapping))
})

test_that("compute_trace_levels returns L0 for unmapped vars without labels", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = "AGEGR1",
    label = NA_character_
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = "AGE",
    label = "Age"
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = NULL)
  levels <- compute_trace_levels(tm)

  expect_equal(levels$trace_level[1], 0L)
  expect_false(levels$has_mapping[1])
  expect_false(levels$has_derivation_text[1])
})

test_that("compute_trace_levels returns L1 for vars with label but no mapping", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = "AGEGR1",
    label = "Age group derived from AGE"
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = "AGE",
    label = "Age"
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = NULL)
  levels <- compute_trace_levels(tm)

  expect_equal(levels$trace_level[1], 1L)
  expect_true(levels$has_derivation_text[1])
  expect_false(levels$has_mapping[1])
})

test_that("compute_trace_levels returns L2 for mapped var without confidence", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = "AGE",
    label = NA_character_
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = "AGE",
    label = "Age"
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE"
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  levels <- compute_trace_levels(tm)

  # has mapping but no confidence and no label -> L2
  expect_equal(levels$trace_level[1], 2L)
})

test_that("compute_trace_levels respects confidence threshold for L3", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = "AGE",
    label = NA_character_
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = "AGE",
    label = "Age"
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE",
    confidence = 0.95
  )

  # Default threshold is 0.8, confidence 0.95 >= 0.8 -> L3
  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  levels <- compute_trace_levels(tm)
  expect_equal(levels$trace_level[1], 3L)

  # With threshold = 0.99, confidence 0.95 < 0.99 -> L2 (no label)
  cfg <- trace_config_default(confidence_threshold_L3 = 0.99)
  tm2 <- build_trace_model(adam_meta, sdtm_meta, mapping = map, config = cfg)
  levels2 <- compute_trace_levels(tm2)
  expect_equal(levels2$trace_level[1], 2L)
})

test_that("compute_trace_levels returns correct n_candidates", {
  adam_meta <- data.frame(
    dataset = "ADAE", variable = "AESTDTC",
    label = "Start Date"
  )
  sdtm_meta <- data.frame(
    dataset = c("AE", "AE"), variable = c("AESTDTC", "AEENDTC"),
    label = c("Start", "End")
  )
  map <- data.frame(
    adam_dataset = c("ADAE", "ADAE"),
    adam_var     = c("AESTDTC", "AESTDTC"),
    sdtm_domain = c("AE", "AE"),
    sdtm_var    = c("AESTDTC", "AEENDTC")
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  levels <- compute_trace_levels(tm)

  expect_equal(levels$n_candidates[1], 2)
})

test_that("compute_trace_levels rejects non-trace_model input", {
  expect_error(compute_trace_levels(list()), "must be a.*trace_model")
})

test_that("compute_trace_levels handles empty adam vars", {
  adam_meta <- data.frame(dataset = character(0), variable = character(0))
  sdtm_meta <- data.frame(dataset = "DM", variable = "AGE")

  tm <- build_trace_model(adam_meta, sdtm_meta)
  levels <- compute_trace_levels(tm)

  expect_equal(nrow(levels), 0)
})
