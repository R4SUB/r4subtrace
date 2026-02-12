test_that("build_trace_model produces correct nodes for small example", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = c("STUDYID", "USUBJID", "AGE"),
    label = c("Study ID", "Subject ID", "Age")
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = c("STUDYID", "USUBJID", "AGE"),
    label = c("Study ID", "Subject ID", "Age")
  )

  tm <- build_trace_model(adam_meta, sdtm_meta)

  expect_s3_class(tm, "trace_model")
  expect_equal(nrow(tm$nodes), 6)  # 3 adam + 3 sdtm
  expect_equal(sum(tm$nodes$role == "adam"), 3)
  expect_equal(sum(tm$nodes$role == "sdtm"), 3)
  expect_true(all(c("node_id", "node_type", "dataset", "variable", "label", "role")
                   %in% names(tm$nodes)))
})

test_that("build_trace_model produces edges from mapping", {
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

  expect_equal(nrow(tm$edges), 2)
  expect_true(all(tm$edges$edge_type == "derived_from"))
  expect_equal(nrow(tm$diagnostics$orphans), 0)
})

test_that("build_trace_model identifies orphans when no mapping", {
  adam_meta <- data.frame(
    dataset = "ADSL", variable = c("STUDYID", "AGE"),
    label = c("Study ID", "Age")
  )
  sdtm_meta <- data.frame(
    dataset = "DM", variable = c("STUDYID", "AGE"),
    label = c("Study ID", "Age")
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = NULL)

  expect_equal(nrow(tm$diagnostics$orphans), 2)
  expect_equal(nrow(tm$edges), 0)
})

test_that("build_trace_model identifies orphans for unmapped vars", {
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

  expect_equal(nrow(tm$diagnostics$orphans), 1)
  expect_equal(tm$diagnostics$orphans$adam_var[1], "AGEGR1")
})

test_that("build_trace_model identifies ambiguities", {
  adam_meta <- data.frame(
    dataset = "ADAE", variable = "AESTDTC",
    label = "Start Date"
  )
  sdtm_meta <- data.frame(
    dataset = c("AE", "AE"), variable = c("AESTDTC", "AEENDTC"),
    label = c("Start Date", "End Date")
  )
  map <- data.frame(
    adam_dataset = c("ADAE", "ADAE"),
    adam_var     = c("AESTDTC", "AESTDTC"),
    sdtm_domain = c("AE", "AE"),
    sdtm_var    = c("AESTDTC", "AEENDTC")
  )

  tm <- build_trace_model(adam_meta, sdtm_meta, mapping = map)

  expect_equal(nrow(tm$diagnostics$ambiguities), 1)
  expect_equal(tm$diagnostics$ambiguities$n_candidates[1], 2)
})

test_that("build_trace_model node IDs are stable/deterministic", {
  adam_meta <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age")
  sdtm_meta <- data.frame(dataset = "DM", variable = "AGE", label = "Age")

  tm1 <- build_trace_model(adam_meta, sdtm_meta)
  tm2 <- build_trace_model(adam_meta, sdtm_meta)

  expect_equal(tm1$nodes$node_id, tm2$nodes$node_id)
})

test_that("print.trace_model does not error", {
  adam_meta <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age")
  sdtm_meta <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
  tm <- build_trace_model(adam_meta, sdtm_meta)

  expect_no_error(print(tm))
})
