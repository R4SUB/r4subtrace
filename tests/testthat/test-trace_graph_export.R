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

test_that("an edgeless model emits nodes but no edges in mermaid and graphml", {
  adam <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age")
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
  tm <- build_trace_model(adam, sdtm)  # no mapping -> no edges

  mm <- export_trace_graph(tm, "mermaid")
  expect_match(mm, "^flowchart LR")
  expect_match(mm, "ADSL.AGE", fixed = TRUE)
  expect_match(mm, "DM.AGE", fixed = TRUE)
  expect_false(grepl("-->", mm, fixed = TRUE))

  gml <- export_trace_graph(tm, "graphml")
  expect_match(gml, "<node ", fixed = TRUE)
  expect_false(grepl("<edge ", gml, fixed = TRUE))
  skip_if_not_installed("xml2")
  expect_s3_class(xml2::read_xml(gml), "xml_document")
})

# --- Special-character escaping -----------------------------------------
# Node labels are "dataset.variable"; variable names are passed through
# untouched (only trimmed), so a variable carrying XML/DOT metacharacters
# exercises each serializer's escaping. Literal characters below:
#   " (double quote), < , > , & , \ (backslash)
special_var <- "A\"<>&\\Z"

make_special_model <- function() {
  adam <- data.frame(
    dataset = "ADSL", variable = special_var, label = "special",
    stringsAsFactors = FALSE
  )
  sdtm <- data.frame(
    dataset = "DM", variable = "AGE", label = "Age",
    stringsAsFactors = FALSE
  )
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = special_var,
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  build_trace_model(adam, sdtm, mapping = map)
}

test_that("DOT escapes quotes and backslashes and leaves angle brackets/ampersand literal", {
  tm <- make_special_model()
  dot <- export_trace_graph(tm, "dot")

  # Structure survives an embedded double quote (it must not terminate label).
  expect_match(dot, "^digraph trace \\{")
  expect_match(dot, "\\}\\s*$")
  expect_equal(lengths(regmatches(dot, gregexpr("->", dot)))[[1]], 1L)

  # Double quote escaped as \" and backslash doubled as \\; <, >, & stay literal
  # (they are not special inside a DOT double-quoted string).
  expect_match(dot, "A\\\"<", fixed = TRUE)    # ...A \" < ...
  expect_match(dot, "&\\\\Z", fixed = TRUE)    # ...& \\ Z ...
  expect_match(dot, "<>&", fixed = TRUE)
  # The fully escaped label, verbatim.
  expect_match(dot, "label=\"ADSL.A\\\"<>&\\\\Z\"", fixed = TRUE)
})

test_that("Mermaid escapes HTML metacharacters as entities and emits no raw markup", {
  tm <- make_special_model()
  mm <- export_trace_graph(tm, "mermaid")

  expect_match(mm, "&quot;", fixed = TRUE)
  expect_match(mm, "&lt;", fixed = TRUE)
  expect_match(mm, "&gt;", fixed = TRUE)
  expect_match(mm, "&amp;", fixed = TRUE)
  # The escaped node label, verbatim.
  expect_match(mm, "[\"ADSL.A&quot;&lt;&gt;&amp;\\Z\"]", fixed = TRUE)
  # A correctly escaped Mermaid document contains no raw '<' (the only '>'
  # comes from the "-->" edge arrows; the label's '>' is escaped above).
  expect_false(grepl("<", mm, fixed = TRUE))
})

test_that("GraphML escapes XML metacharacters and parses as well-formed XML", {
  tm <- make_special_model()
  gml <- export_trace_graph(tm, "graphml")

  expect_match(gml, "&amp;", fixed = TRUE)
  expect_match(gml, "&lt;", fixed = TRUE)
  expect_match(gml, "&gt;", fixed = TRUE)
  expect_match(gml, "&quot;", fixed = TRUE)
  # The label element content, verbatim (backslash is literal in XML text).
  expect_match(
    gml,
    "<data key=\"label\">ADSL.A&quot;&lt;&gt;&amp;\\Z</data>",
    fixed = TRUE
  )

  skip_if_not_installed("xml2")
  doc <- xml2::read_xml(gml)  # errors if not well-formed
  labels <- xml2::xml_text(
    xml2::xml_find_all(doc, "//*[local-name()='data' and @key='label']")
  )
  # Round-trips back to the exact original label, proving escaping is reversible.
  expect_true(paste0("ADSL.", special_var) %in% labels)
})

# --- include_isolated edge cases ----------------------------------------

test_that("include_isolated = FALSE on an edgeless model yields a valid, nodeless graph", {
  adam <- data.frame(dataset = "ADSL", variable = "AGE", label = "Age")
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age")
  tm <- build_trace_model(adam, sdtm)  # no edges at all

  dot <- export_trace_graph(tm, "dot", include_isolated = FALSE)
  expect_match(dot, "^digraph trace \\{")
  expect_match(dot, "\\}\\s*$")
  expect_false(grepl("ADSL.AGE", dot, fixed = TRUE))
  expect_false(grepl("DM.AGE", dot, fixed = TRUE))
  expect_equal(lengths(regmatches(dot, gregexpr("->", dot)))[[1]], 0L)

  mm <- export_trace_graph(tm, "mermaid", include_isolated = FALSE)
  expect_match(mm, "^flowchart LR")
  expect_false(grepl("-->", mm, fixed = TRUE))
  expect_false(grepl("ADSL.AGE", mm, fixed = TRUE))
})

test_that("include_isolated keeps edge endpoints, even ones absent from the model", {
  tm <- make_export_model()
  # Derivation references ADAE.AAGE (in model) -> ADSL.NEWDERIV (NOT a model node).
  deriv <- data.frame(
    from_dataset = "ADAE", from_var = "AAGE",
    to_dataset   = "ADSL", to_var  = "NEWDERIV",
    stringsAsFactors = FALSE
  )

  full <- export_trace_graph(tm, "dot", adam_derivations = deriv)
  # An edge endpoint missing from the model is still emitted as a node.
  expect_match(full, "ADSL.NEWDERIV", fixed = TRUE)

  trimmed <- export_trace_graph(
    tm, "dot", adam_derivations = deriv, include_isolated = FALSE
  )
  # Kept because it participates in an edge, despite not being a model node.
  expect_match(trimmed, "ADSL.NEWDERIV", fixed = TRUE)
  expect_match(trimmed, "ADAE.AAGE", fixed = TRUE)
  # Genuinely isolated nodes are dropped.
  expect_false(grepl("ORPHAN", trimmed, fixed = TRUE))
  expect_false(grepl("UNUSED", trimmed, fixed = TRUE))
})

# --- ADaM-to-ADaM derivations -------------------------------------------

test_that("ADaM-to-ADaM derivations add adam-role nodes and chain edges", {
  # Model edge: ADSL.AGE -> DM.AGE. Derivations: ADAE.AAGE -> ADSL.AGE
  # (adam->adam, then grounded via the mapping) and ADLB.BASE -> ADLB.AVAL
  # (adam->adam, with no SDTM grounding).
  adam <- data.frame(
    dataset  = c("ADSL", "ADAE", "ADLB", "ADLB"),
    variable = c("AGE", "AAGE", "AVAL", "BASE"),
    label    = NA_character_, stringsAsFactors = FALSE
  )
  sdtm <- data.frame(dataset = "DM", variable = "AGE", label = "Age",
                     stringsAsFactors = FALSE)
  map <- data.frame(
    adam_dataset = "ADSL", adam_var = "AGE",
    sdtm_domain = "DM", sdtm_var = "AGE", confidence = 1,
    stringsAsFactors = FALSE
  )
  tm <- build_trace_model(adam, sdtm, mapping = map)
  deriv <- data.frame(
    from_dataset = c("ADAE", "ADLB"),
    from_var     = c("AAGE", "BASE"),
    to_dataset   = c("ADSL", "ADLB"),
    to_var       = c("AGE", "AVAL"),
    stringsAsFactors = FALSE
  )

  dot <- export_trace_graph(tm, "dot", adam_derivations = deriv)
  # Three edges total: AAGE->AGE, BASE->AVAL, AGE->DM.AGE.
  expect_equal(lengths(regmatches(dot, gregexpr("->", dot)))[[1]], 3L)
  # Four ADaM nodes (blue fill), one SDTM node (orange fill).
  expect_equal(lengths(regmatches(dot, gregexpr("#2C6DB5", dot)))[[1]], 4L)
  expect_equal(lengths(regmatches(dot, gregexpr("#F39C12", dot)))[[1]], 1L)
  expect_match(dot, "ADAE.AAGE", fixed = TRUE)
  expect_match(dot, "ADLB.BASE", fixed = TRUE)
  expect_match(dot, "ADLB.AVAL", fixed = TRUE)

  # In Mermaid, all four ADaM nodes are assigned to the adam class.
  mm <- export_trace_graph(tm, "mermaid", adam_derivations = deriv)
  adam_assign <- regmatches(mm, regexpr("class [^ ]+ adam;", mm))
  ids_str <- sub("^class ([^ ]+) adam;$", "\\1", adam_assign)
  expect_equal(length(strsplit(ids_str, ",")[[1]]), 4L)
})

# --- file writing round-trips -------------------------------------------

test_that("file output round-trips for mermaid and graphml", {
  tm <- make_export_model()
  deriv <- export_derivations()

  for (fmt in c("mermaid", "graphml")) {
    path <- tempfile()
    on.exit(unlink(path), add = TRUE)
    res <- expect_invisible(
      suppressMessages(
        export_trace_graph(tm, fmt, adam_derivations = deriv, file = path)
      )
    )
    expect_true(file.exists(path))
    expect_equal(paste(readLines(path), collapse = "\n"), res)
  }

  # The written GraphML file is itself well-formed XML on disk.
  skip_if_not_installed("xml2")
  path <- tempfile(fileext = ".graphml")
  on.exit(unlink(path), add = TRUE)
  suppressMessages(
    export_trace_graph(tm, "graphml", adam_derivations = deriv, file = path)
  )
  expect_s3_class(xml2::read_xml(path), "xml_document")
})
