# Tests for multi-step derivation chains (R/trace_chains.R)

make_chain_model <- function() {
  adam <- data.frame(
    dataset  = c("ADSL", "ADSL", "ADSL", "ADSL", "ADAE", "ADTTE"),
    variable = c("AGE", "FOO", "A", "B", "AAGE", "TAGE"),
    label    = c("Age", "Foo", "A", "B", "Analysis Age", "Time Age"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age",
                     stringsAsFactors = FALSE)
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  build_trace_model(adam, sdtm, mapping = map)
}

chain_derivations <- function() {
  data.frame(
    from_dataset = c("ADAE", "ADTTE"),
    from_var     = c("AAGE", "TAGE"),
    to_dataset   = c("ADSL", "ADAE"),
    to_var       = c("AGE", "AAGE"),
    stringsAsFactors = FALSE
  )
}

# The clean chains plus a two-node cycle A <-> B.
chain_derivations_with_cycle <- function() {
  rbind(
    chain_derivations(),
    data.frame(
      from_dataset = c("ADSL", "ADSL"),
      from_var     = c("A", "B"),
      to_dataset   = c("ADSL", "ADSL"),
      to_var       = c("B", "A"),
      stringsAsFactors = FALSE
    )
  )
}

get_row <- function(chains, ds, var) {
  chains[chains$adam_dataset == ds & chains$adam_var == var, ]
}

test_that("a two-step chain grounds to SDTM", {
  tm <- make_chain_model()
  chains <- suppressMessages(trace_chains(tm, chain_derivations()))

  aage <- get_row(chains, "ADAE", "AAGE")
  expect_true(aage$grounded)
  expect_equal(aage$max_depth, 2L)
  expect_match(aage$longest_chain, "ADAE.AAGE -> ADSL.AGE -> DM.AGE", fixed = TRUE)
  expect_equal(aage$terminal_source, "DM.AGE")
})

test_that("a three-step chain grounds to SDTM", {
  tm <- make_chain_model()
  chains <- suppressMessages(trace_chains(tm, chain_derivations()))

  tage <- get_row(chains, "ADTTE", "TAGE")
  expect_true(tage$grounded)
  expect_equal(tage$max_depth, 3L)
  expect_match(tage$longest_chain, "DM.AGE", fixed = TRUE)
})

test_that("a variable with no source is ungrounded", {
  tm <- make_chain_model()
  chains <- suppressMessages(trace_chains(tm, chain_derivations()))

  foo <- get_row(chains, "ADSL", "FOO")
  expect_false(foo$grounded)
  expect_equal(foo$max_depth, 0L)
  expect_false(foo$has_cycle)
})

test_that("a direct mapping is a one-step grounded chain", {
  tm <- make_chain_model()
  chains <- suppressMessages(trace_chains(tm, chain_derivations()))

  age <- get_row(chains, "ADSL", "AGE")
  expect_true(age$grounded)
  expect_equal(age$max_depth, 1L)
})

test_that("circular references are detected and warned", {
  tm <- make_chain_model()
  expect_warning(
    chains <- trace_chains(tm, chain_derivations_with_cycle()),
    "[Cc]ircular"
  )
  a <- get_row(chains, "ADSL", "A")
  expect_true(a$has_cycle)
  expect_false(a$grounded)
})

test_that("trace_depth caps the walk and flags truncation", {
  tm <- make_chain_model()
  shallow <- suppressMessages(trace_chains(tm, chain_derivations(), trace_depth = 1L))

  tage <- get_row(shallow, "ADTTE", "TAGE")
  expect_true(tage$truncated)
  expect_false(tage$grounded)
  expect_equal(tage$max_depth, 1L)
})

test_that("chains work without any ADaM-to-ADaM derivations", {
  tm <- make_chain_model()
  chains <- suppressMessages(trace_chains(tm))

  # AGE still grounds through the direct mapping.
  expect_true(get_row(chains, "ADSL", "AGE")$grounded)
  # AAGE has no source now, so it is ungrounded.
  expect_false(get_row(chains, "ADAE", "AAGE")$grounded)
})

test_that("inputs are validated", {
  tm <- make_chain_model()
  expect_error(trace_chains(tm, trace_depth = 0), "positive")
  expect_error(trace_chains(list()), "trace_model")
  bad <- data.frame(from_dataset = "ADAE", from_var = "AAGE")
  expect_error(suppressMessages(trace_chains(tm, bad)), "to_dataset")
})
