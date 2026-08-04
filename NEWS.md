# r4subtrace (development version)

- Add `export_traceability_report()` and `traceability_coverage()`, which
  summarize traceability coverage per ADaM dataset (percent traced, untraced
  variables listed) with an overall summary row, and export the table as a
  data.frame, CSV, or Excel file for ADRG appendices.
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
