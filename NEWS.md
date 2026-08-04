# r4subtrace 0.2.1

- Add `trace_problems()`, a focused view of just the traceability issues worth
  acting on: variables that are not traced to the required level, and, when a
  derivation table is supplied, chains that never reach SDTM, that are circular,
  or that were cut off at the depth limit. On a large submission this is what a
  team consumes rather than the full per-variable coverage table. The engine is
  verified on a 10,000-variable synthetic model.

# r4subtrace 0.2.0

- Add `export_traceability_report()` and `traceability_coverage()`, which
  summarize traceability coverage per ADaM dataset (percent traced, untraced
  variables listed) with an overall summary row, and export the table as a
  data.frame, CSV, or Excel file for ADRG appendices.
- Add `trace_chains()`, which follows multi-step derivation chains back to
  source (ADaM derived from ADaM derived from SDTM), reports the depth and
  whether each variable is grounded in SDTM, caps the walk with `trace_depth`,
  and detects circular references. Add `plot_trace_graph()` to draw the
  derivation graph with `igraph`.
- Add vignette: "Case study: tracing ADaM back to SDTM", a worked walkthrough
  building a trace model from the example CDISC pilot metadata in `r4subdata`,
  finding orphan variables, and reading the coverage indicators.
- Clarified the package DESCRIPTION: "R4SUB" expands to "Ready for Submission"
  (previously "R for Regulatory Submission", inconsistent with the rest of the
  ecosystem).

# r4subtrace 0.1.1

- Add vignette: "Traceability Analysis with r4subtrace" covering
  `build_trace_model()`, `compute_trace_levels()`, `trace_indicator_scores()`,
  and orphan variable detection.

# r4subtrace 0.1.0

- Initial CRAN release.
