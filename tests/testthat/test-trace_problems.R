# Tests for trace_problems and behavior at scale (R/trace_problems.R)

test_that("a fully traced model has no problems", {
  adam <- data.frame(dataset = "ADSL", variable = c("USUBJID", "AGE"),
                     label = c("Subject", "Age"))
  sdtm <- data.frame(dataset = "DM", variable = c("USUBJID", "AGE"))
  map  <- data.frame(adam_dataset = "ADSL", adam_var = c("USUBJID", "AGE"),
                     sdtm_domain = "DM", sdtm_var = c("USUBJID", "AGE"),
                     confidence = c(1, 1))
  tm <- build_trace_model(adam, sdtm, mapping = map)
  expect_equal(nrow(trace_problems(tm)), 0L)
})

test_that("an untraced variable is reported", {
  adam <- data.frame(dataset = "ADSL", variable = c("USUBJID", "ORPHAN"),
                     label = c("Subject", "Orphan"))
  sdtm <- data.frame(dataset = "DM", variable = "USUBJID")
  map  <- data.frame(adam_dataset = "ADSL", adam_var = "USUBJID",
                     sdtm_domain = "DM", sdtm_var = "USUBJID", confidence = 1)
  tm <- build_trace_model(adam, sdtm, mapping = map)
  p <- trace_problems(tm)
  orphan <- p[p$adam_var == "ORPHAN", ]
  expect_equal(nrow(orphan), 1L)
  expect_equal(orphan$problem, "untraced")
})

test_that("an ungrounded derivation chain is reported", {
  adam <- data.frame(dataset = "ADSL", variable = c("AGE", "FOO", "BAR"),
                     label = c("Age", "Foo", "Bar"))
  sdtm <- data.frame(dataset = "DM", variable = "AGE")
  map  <- data.frame(adam_dataset = "ADSL", adam_var = "AGE",
                     sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1)
  tm <- build_trace_model(adam, sdtm, mapping = map)
  deriv <- data.frame(from_dataset = "ADSL", from_var = "BAR",
                      to_dataset = "ADSL", to_var = "FOO")
  p <- trace_problems(tm, adam_derivations = deriv)
  bar <- p[p$adam_var == "BAR" & p$problem == "ungrounded", ]
  expect_equal(nrow(bar), 1L)
})

test_that("a circular derivation chain is reported", {
  adam <- data.frame(dataset = "ADSL", variable = c("X", "Y"),
                     label = c("X", "Y"))
  sdtm <- data.frame(dataset = "DM", variable = "USUBJID")
  tm <- build_trace_model(adam, sdtm)   # no mapping: X and Y have no SDTM source
  deriv <- data.frame(from_dataset = c("ADSL", "ADSL"),
                      from_var = c("X", "Y"),
                      to_dataset = c("ADSL", "ADSL"),
                      to_var = c("Y", "X"))
  p <- suppressWarnings(trace_problems(tm, adam_derivations = deriv))
  expect_true("cycle" %in% p$problem)
})

# --- Scale benchmark -----------------------------------------------------------
# Build a large synthetic model and confirm the summaries stay correct and
# usable. This is the regression guard for traceability at real submission size.

synthetic_inputs <- function(n_datasets, vars_per, mapped_frac) {
  ds <- sprintf("AD%03d", seq_len(n_datasets))
  adam <- do.call(rbind, lapply(ds, function(d) {
    data.frame(dataset = d,
               variable = sprintf("V%03d", seq_len(vars_per)),
               label = "v", stringsAsFactors = FALSE)
  }))
  n_mapped <- floor(vars_per * mapped_frac)
  sdtm <- data.frame(dataset = "DM",
                     variable = sprintf("S%03d", seq_len(n_mapped)),
                     stringsAsFactors = FALSE)
  map <- do.call(rbind, lapply(ds, function(d) {
    data.frame(adam_dataset = d,
               adam_var = sprintf("V%03d", seq_len(n_mapped)),
               sdtm_domain = "DM",
               sdtm_var = sprintf("S%03d", seq_len(n_mapped)),
               confidence = 1, stringsAsFactors = FALSE)
  }))
  list(adam = adam, sdtm = sdtm, map = map,
       n_total = n_datasets * vars_per,
       n_untraced = n_datasets * (vars_per - n_mapped))
}

test_that("the summaries are correct and complete at scale", {
  # 100 datasets x 100 variables = 10,000 variables, a realistic submission size.
  inp <- synthetic_inputs(n_datasets = 100, vars_per = 100, mapped_frac = 0.8)
  tm <- build_trace_model(inp$adam, inp$sdtm, mapping = inp$map)

  cov <- traceability_coverage(tm)
  expect_equal(nrow(cov), 100L)
  expect_true(all(cov$n_variables == 100L))

  prob <- trace_problems(tm)
  expect_equal(nrow(prob), inp$n_untraced)          # 100 * 20 = 2000
  expect_true(all(prob$problem == "untraced"))
})
