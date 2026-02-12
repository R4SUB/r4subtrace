test_that("trace_indicator_scores returns expected metrics", {
  skip_if_not_installed("r4subcore")

  ctx <- r4subcore::r4sub_run_context(study_id = "TEST001", environment = "DEV")
  adam_meta <- data.frame(
    dataset = "ADSL", variable = c("STUDYID", "AGE", "AGEGR1"),
    label = c("Study ID", "Age", "Age Group")
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
  ev <- trace_model_to_evidence(tm, ctx = ctx)
  ind <- trace_indicator_scores(ev)

  expect_s3_class(ind, "tbl_df")
  expect_true(all(c("indicator", "value", "description") %in% names(ind)))
  expect_equal(nrow(ind), 5)

  # 2 out of 3 vars are mapped -> L3, 1 orphan with label -> still gets L1 via TRACE_LEVEL
  coverage_l2 <- ind$value[ind$indicator == "TRACE_VAR_COVERAGE_L2PLUS"]
  expect_true(coverage_l2 > 0 && coverage_l2 <= 1)

  orphan_count <- ind$value[ind$indicator == "TRACE_ORPHAN_VAR_COUNT"]
  expect_equal(orphan_count, 1)
})

test_that("trace_indicator_scores handles all-mapped scenario", {
  skip_if_not_installed("r4subcore")

  ctx <- r4subcore::r4sub_run_context(study_id = "TEST001", environment = "DEV")
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
  ev <- trace_model_to_evidence(tm, ctx = ctx)
  ind <- trace_indicator_scores(ev)

  coverage_l2 <- ind$value[ind$indicator == "TRACE_VAR_COVERAGE_L2PLUS"]
  expect_equal(coverage_l2, 1.0)

  orphan_count <- ind$value[ind$indicator == "TRACE_ORPHAN_VAR_COUNT"]
  expect_equal(orphan_count, 0)

  ambig_count <- ind$value[ind$indicator == "TRACE_AMBIGUOUS_MAPPING_COUNT"]
  expect_equal(ambig_count, 0)
})

test_that("trace_indicator_scores rejects non-data.frame", {
  expect_error(trace_indicator_scores("not_a_df"), "must be a data.frame")
})

test_that("trace_indicator_scores works with ambiguities", {
  skip_if_not_installed("r4subcore")

  ctx <- r4subcore::r4sub_run_context(study_id = "TEST001", environment = "DEV")
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
  ev <- trace_model_to_evidence(tm, ctx = ctx)
  ind <- trace_indicator_scores(ev)

  ambig_count <- ind$value[ind$indicator == "TRACE_AMBIGUOUS_MAPPING_COUNT"]
  expect_equal(ambig_count, 1)
})
