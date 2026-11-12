# Tests for derivation graph export (R/trace_graph_export.R)

make_export_model <- function() {
  adam <- data.frame(
    dataset  = c("ADSL", "ADSL", "ADAE"),
    variable = c("AGE", "ORPHAN", "AAGE"),
    label    = c("Age", "Orphan", "Analysis Age"),
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(
    dataset  = c("DM", "DM"),
    variable = c("AGE", "UNUSED"),
    label    = c("Age", "Unused"),
    stringsAsFactors = FALSE
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  build_trace_model(adam, sdtm, mapping = map)
}

export_derivations <- function() {
  data.frame(
    from_dataset = "ADAE", from_var = "AAGE",
    to_dataset   = "ADSL", to_var  = "AGE",
    stringsAsFactors = FALSE
  )
}

test_that("format is validated and an unknown format errors", {
  tm <- make_export_model()
  expect_error(export_trace_graph(tm, "svg"), "format")
  expect_error(export_trace_graph(list(), "dot"), "trace_model")
})

test_that("DOT output is a well-formed digraph with nodes and edges", {
  tm <- make_export_model()
  dot <- export_trace_graph(tm, "dot", adam_derivations = export_derivations())

  expect_length(dot, 1L)
  expect_match(dot, "^digraph trace \\{")
  expect_match(dot, "\\}\\s*$")
  # Direct mapping edge ADSL.AGE -> DM.AGE and the chain edge both present.
  expect_match(dot, "label=\"ADSL.AGE\"", fixed = TRUE)
  expect_match(dot, "label=\"DM.AGE\"", fixed = TRUE)
  expect_match(dot, "label=\"ADAE.AAGE\"", fixed = TRUE)
  # Two edges: AGE->DM.AGE and AAGE->AGE.
  expect_equal(lengths(regmatches(dot, gregexpr("->", dot)))[[1]], 2L)
  # SDTM node coloured differently from ADaM.
  expect_match(dot, "#F39C12", fixed = TRUE)
  expect_match(dot, "#2C6DB5", fixed = TRUE)
})

test_that("isolated nodes are included by default and dropped on request", {
  tm <- make_export_model()

  with_iso <- export_trace_graph(tm, "dot")
  expect_match(with_iso, "ORPHAN", fixed = TRUE)
  expect_match(with_iso, "UNUSED", fixed = TRUE)

  without_iso <- export_trace_graph(tm, "dot", include_isolated = FALSE)
  expect_false(grepl("ORPHAN", without_iso, fixed = TRUE))
  expect_false(grepl("UNUSED", without_iso, fixed = TRUE))
  # The mapped pair survives.
  expect_match(without_iso, "ADSL.AGE", fixed = TRUE)
  expect_match(without_iso, "DM.AGE", fixed = TRUE)
})

test_that("Mermaid output declares a flowchart with classes", {
  tm <- make_export_model()
  mm <- export_trace_graph(tm, "mermaid", adam_derivations = export_derivations())

  expect_match(mm, "^flowchart LR")
  expect_match(mm, "-->", fixed = TRUE)
  expect_match(mm, "classDef adam", fixed = TRUE)
  expect_match(mm, "classDef sdtm", fixed = TRUE)
  expect_match(mm, "class ", fixed = TRUE)
})

test_that("GraphML output is namespaced XML with node roles", {
  tm <- make_export_model()
  gml <- export_trace_graph(tm, "graphml", adam_derivations = export_derivations())

  expect_match(gml, "^<\\?xml")
  expect_match(gml, "graphml.graphdrawing.org", fixed = TRUE)
  expect_match(gml, "<data key=\"role\">adam</data>", fixed = TRUE)
  expect_match(gml, "<data key=\"role\">sdtm</data>", fixed = TRUE)
  expect_match(gml, "edgedefault=\"directed\"", fixed = TRUE)
  # One <edge> per derivation edge.
  expect_equal(lengths(regmatches(gml, gregexpr("<edge ", gml)))[[1]], 2L)
})

test_that("file output writes the text and returns it invisibly", {
  tm <- make_export_model()
  path <- tempfile(fileext = ".dot")
  on.exit(unlink(path), add = TRUE)

  res <- expect_invisible(
    suppressMessages(export_trace_graph(tm, "dot", file = path))
  )
  expect_true(file.exists(path))
  written <- paste(readLines(path), collapse = "\n")
  expect_equal(written, res)
})

test_that("a model with no edges still emits all nodes and no edges", {
  adam <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age")
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
  tm <- build_trace_model(adam, sdtm)  # no mapping -> no edges

  dot <- export_trace_graph(tm, "dot")
  expect_match(dot, "ADSL.AGE", fixed = TRUE)
  expect_match(dot, "DM.AGE", fixed = TRUE)
  expect_equal(lengths(regmatches(dot, gregexpr("->", dot)))[[1]], 0L)
})
