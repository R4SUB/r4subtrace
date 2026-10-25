# Changelog

## r4subtrace 0.3.1

- Complete the pkgdown reference index so the documentation site builds,
  and polish metadata for CRAN.

## r4subtrace 0.3.0

- Add
  [`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md),
  impact analysis for a changed source variable. Given a variable that
  is about to change, it walks the derivation graph in reverse and
  returns every ADaM variable that derives from it, directly or through
  a chain, each with its distance from the change and a readable path
  back to it. This is the question a data team asks before editing a
  source: what breaks downstream. Circular references are handled and
  multi-step chains are followed through `adam_derivations`, the same
  input
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
  uses.

## r4subtrace 0.2.1

- Add
  [`trace_problems()`](https://r4sub.github.io/r4subtrace/reference/trace_problems.md),
  a focused view of just the traceability issues worth acting on:
  variables that are not traced to the required level, and, when a
  derivation table is supplied, chains that never reach SDTM, that are
  circular, or that were cut off at the depth limit. On a large
  submission this is what a team consumes rather than the full
  per-variable coverage table. The engine is verified on a
  10,000-variable synthetic model.

## r4subtrace 0.2.0

- Add
  [`export_traceability_report()`](https://r4sub.github.io/r4subtrace/reference/export_traceability_report.md)
  and
  [`traceability_coverage()`](https://r4sub.github.io/r4subtrace/reference/traceability_coverage.md),
  which summarize traceability coverage per ADaM dataset (percent
  traced, untraced variables listed) with an overall summary row, and
  export the table as a data.frame, CSV, or Excel file for ADRG
  appendices.
- Add
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md),
  which follows multi-step derivation chains back to source (ADaM
  derived from ADaM derived from SDTM), reports the depth and whether
  each variable is grounded in SDTM, caps the walk with `trace_depth`,
  and detects circular references. Add
  [`plot_trace_graph()`](https://r4sub.github.io/r4subtrace/reference/plot_trace_graph.md)
  to draw the derivation graph with `igraph`.
- Add vignette: “Case study: tracing ADaM back to SDTM”, a worked
  walkthrough building a trace model from the example CDISC pilot
  metadata in `r4subdata`, finding orphan variables, and reading the
  coverage indicators.
- Clarified the package DESCRIPTION: “R4SUB” expands to “Ready for
  Submission” (previously “R for Regulatory Submission”, inconsistent
  with the rest of the ecosystem).

## r4subtrace 0.1.1

- Add vignette: “Traceability Analysis with r4subtrace” covering
  [`build_trace_model()`](https://r4sub.github.io/r4subtrace/reference/build_trace_model.md),
  [`compute_trace_levels()`](https://r4sub.github.io/r4subtrace/reference/compute_trace_levels.md),
  [`trace_indicator_scores()`](https://r4sub.github.io/r4subtrace/reference/trace_indicator_scores.md),
  and orphan variable detection.

## r4subtrace 0.1.0

CRAN release: 2026-03-03

- Initial CRAN release.
