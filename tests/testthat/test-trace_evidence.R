test_that("trace_model_to_evidence returns valid evidence", {
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
    sdtm_domain = "DM", sdtm_var = c("STUDYID", "AGE")
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  ev <- trace_model_to_evidence(tm, ctx = ctx)

  expect_true(r4subcore::validate_evidence(ev))
  expect_true(nrow(ev) >= 2)  # at least 2 var-level rows
})

test_that("trace_model_to_evidence emits TRACE_LEVEL rows", {
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

  level_rows <- ev[ev$indicator_id == "TRACE_LEVEL", ]
  expect_equal(nrow(level_rows), 2)
  expect_true(all(level_rows$indicator_domain == "trace"))
  expect_true(all(level_rows$metric_value == 3))  # L3: mapped + label + confidence
})

test_that("trace_model_to_evidence emits orphan rows", {
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
    sdtm_domain = "DM", sdtm_var = c("STUDYID", "AGE")
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  ev <- trace_model_to_evidence(tm, ctx = ctx)

  orphan_rows <- ev[ev$indicator_id == "TRACE_ORPHAN_VAR", ]
  expect_equal(nrow(orphan_rows), 1)
  expect_equal(orphan_rows$severity[1], "high")
  expect_equal(orphan_rows$result[1], "fail")
})

test_that("trace_model_to_evidence emits ambiguity rows", {
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

  ambig_rows <- ev[ev$indicator_id == "TRACE_AMBIGUOUS_MAPPING", ]
  expect_equal(nrow(ambig_rows), 1)
  expect_equal(ambig_rows$severity[1], "medium")
  expect_equal(ambig_rows$result[1], "warn")
})

test_that("trace_model_to_evidence sets correct severity per trace level", {
  skip_if_not_installed("r4subcore")

  ctx <- r4subcore::r4sub_run_context(study_id = "TEST001", environment = "DEV")

  # One var L0 (no mapping, no label), one L3 (mapped + label + high confidence)
  adam_meta <- data.frame(
    dataset = "ADSL", variable = c("AGE", "MYVAR"),
    label = c("Age", NA_character_)
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = "AGE",
    label = "Age"
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE",
    confidence = 0.9
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)
  ev <- trace_model_to_evidence(tm, ctx = ctx)

  level_rows <- ev[ev$indicator_id == "TRACE_LEVEL", ]
  # Sort by metric_value to find L0 and L3
  l0 <- level_rows[level_rows$metric_value == 0, ]
  l3 <- level_rows[level_rows$metric_value == 3, ]

  expect_equal(l0$severity[1], "high")
  expect_equal(l0$result[1], "fail")
  expect_equal(l3$severity[1], "info")
  expect_equal(l3$result[1], "pass")
})

test_that("trace_model_to_evidence sets source_name and source_version", {
  skip_if_not_installed("r4subcore")

  ctx <- r4subcore::r4sub_run_context(study_id = "TEST001", environment = "DEV")
  adam_meta <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age")
  sdtm_meta <- data.frame(dataset = "DM", variable = "AGE", label = "Age")

  tm <- build_trace_model(adam_meta, sdtm_meta)
  ev <- trace_model_to_evidence(tm, ctx = ctx, source_name = "my_tool",
                                 source_version = "1.2.3")

  expect_true(all(ev$source_name == "my_tool"))
  expect_true(all(ev$source_version == "1.2.3"))
})
