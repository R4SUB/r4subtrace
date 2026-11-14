# Changelog

## r4subtrace (development version)

- Add
  [`export_trace_graph()`](https://r4sub.github.io/r4subtrace/reference/export_trace_graph.md),
  which serializes the derivation graph behind
  [`trace_chains()`](https://r4sub.github.io/r4subtrace/reference/trace_chains.md)
  to a portable text format: Graphviz DOT, Mermaid, or GraphML. Unlike
  [`plot_trace_graph()`](https://r4sub.github.io/r4subtrace/reference/plot_trace_graph.md),
  which needs `igraph` and only renders interactively, the text can be
  committed to version control, embedded in an ADRG or vignette,
  rendered by Graphviz, or opened in a graph editor. Edges run from a
  derived variable to its source, ADaM-to-ADaM derivations are included
  when supplied, and every variable node is emitted so orphans and
  unused SDTM sources show as isolated nodes. Pure serialization: trace
  levels, coverage, and scoring are unchanged.
- Complete the pkgdown reference index with
  [`sdtm_utilization()`](https://r4sub.github.io/r4subtrace/reference/sdtm_utilization.md),
  [`summarize_impact()`](https://r4sub.github.io/r4subtrace/reference/summarize_impact.md),
  and
  [`export_impact_report()`](https://r4sub.github.io/r4subtrace/reference/export_impact_report.md),
  which were exported but missing from the documentation site index.
- Add
  [`export_impact_report()`](https://r4sub.github.io/r4subtrace/reference/export_impact_report.md)
  and
  [`summarize_impact()`](https://r4sub.github.io/r4subtrace/reference/summarize_impact.md),
  which turn the result of
  [`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
  into reportable form.
  [`summarize_impact()`](https://r4sub.github.io/r4subtrace/reference/summarize_impact.md)
  prints a short digest and rolls up the affected downstream variables
  by dataset and by level (distance from the change);
  [`export_impact_report()`](https://r4sub.github.io/r4subtrace/reference/export_impact_report.md)
  writes the full affected list, with paths and the changed variable, to
  a data.frame, CSV, or Excel file for a change-control record.
  Reporting only:
  [`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
  and the derivation graph are unchanged.
- Add
  [`sdtm_utilization()`](https://r4sub.github.io/r4subtrace/reference/sdtm_utilization.md),
  the mirror image of orphan detection. Given a trace model, it reports
  which SDTM source variables are referenced by no ADaM variable, the
  dead or unused sources in a submission, with a per-variable
  used-count. It reuses the same reverse adjacency as
  [`trace_impact()`](https://r4sub.github.io/r4subtrace/reference/trace_impact.md)
  and is a pure diagnostic: trace levels, coverage, and scoring are
  unchanged.
- Import `%||%` from `rlang` explicitly. It was used in
  [`trace_model_to_evidence()`](https://r4sub.github.io/r4subtrace/reference/trace_model_to_evidence.md)
  but relied on the base R `%||%`, which only exists from R 4.4.0, so
  evidence emission could fail on the R 4.2/4.3 versions the package
  still declares support for. No change to traceability behavior.

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
