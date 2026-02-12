test_that("validate_metadata canonicalizes column names", {
  df <- data.frame(DATASET = "ADSL", VARIABLE = "AGE", LABEL = "Age")
  result <- validate_metadata(df, kind = "adam")
  expect_true(all(c("dataset", "variable", "label") %in% names(result)))
  expect_s3_class(result, "tbl_df")
})

test_that("validate_metadata errors on missing required columns", {
  df <- data.frame(var = "AGE", label = "Age")
  expect_error(validate_metadata(df, kind = "adam"), "missing required column")
})

test_that("validate_metadata fills optional columns with NA", {
  df <- data.frame(dataset = "ADSL", variable = "AGE")
  result <- validate_metadata(df, kind = "sdtm")
  expect_true("label" %in% names(result))
  expect_true("type" %in% names(result))
  expect_true(is.na(result$label[1]))
})

test_that("validate_metadata trims whitespace", {
  df <- data.frame(dataset = "  ADSL  ", variable = "  AGE  ")
  result <- validate_metadata(df, kind = "adam")
  expect_equal(result$dataset[1], "ADSL")
  expect_equal(result$variable[1], "AGE")
})

test_that("validate_metadata rejects non-data.frame input", {
  expect_error(validate_metadata("not_a_df", kind = "adam"), "must be a data.frame")
})

test_that("validate_mapping canonicalizes and uppercases", {
  df <- data.frame(
    ADAM_DATASET = "adsl", ADAM_VAR = "age",
    SDTM_DOMAIN = "dm", SDTM_VAR = "age"
  )
  result <- validate_mapping(df)
  expect_equal(result$adam_dataset[1], "ADSL")
  expect_equal(result$sdtm_domain[1], "DM")
  expect_s3_class(result, "tbl_df")
})

test_that("validate_mapping handles case-insensitive columns with dots", {
  df <- data.frame(
    Adam.Dataset = "ADSL", Adam.Var = "AGE",
    Sdtm.Domain = "DM", Sdtm.Var = "AGE"
  )
  result <- validate_mapping(df)
  expect_true(all(c("adam_dataset", "adam_var", "sdtm_domain", "sdtm_var") %in% names(result)))
})

test_that("validate_mapping errors on missing required columns", {
  df <- data.frame(adam_dataset = "ADSL", adam_var = "AGE")
  expect_error(validate_mapping(df), "missing required column")
})

test_that("validate_mapping fills optional columns", {
  df <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE"
  )
  result <- validate_mapping(df)
  expect_true("derivation_text" %in% names(result))
  expect_true("confidence" %in% names(result))
  expect_true(is.na(result$derivation_text[1]))
})

test_that("validate_mapping respects uppercase_datasets = FALSE", {
  df <- data.frame(
    adam_dataset = "adsl", adam_var = "age",
    sdtm_domain = "dm", sdtm_var = "age"
  )
  result <- validate_mapping(df, uppercase_datasets = FALSE)
  expect_equal(result$adam_dataset[1], "adsl")
  expect_equal(result$sdtm_domain[1], "dm")
})
