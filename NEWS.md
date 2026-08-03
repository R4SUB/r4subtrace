# r4subtrace (development version)

- Add `trace_chains()`, which follows multi-step derivation chains back to
  source (ADaM derived from ADaM derived from SDTM), reports the depth and
  whether each variable is grounded in SDTM, caps the walk with `trace_depth`,
  and detects circular references. Add `plot_trace_graph()` to draw the
  derivation graph with `igraph`.

- Clarified the package DESCRIPTION: "R4SUB" expands to "Ready for Submission"
  (previously "R for Regulatory Submission", inconsistent with the rest of the
  ecosystem).

# r4subtrace 0.1.1

- Add vignette: "Traceability Analysis with r4subtrace" covering
  `build_trace_model()`, `compute_trace_levels()`, `trace_indicator_scores()`,
  and orphan variable detection.

# r4subtrace 0.1.0

- Initial CRAN release.
