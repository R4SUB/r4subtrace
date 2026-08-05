## Submission

This is an update of r4subtrace from 0.1.0 (on CRAN) to 0.2.1, a feature release
for the R4SUB (Ready for Submission) ecosystem. Highlights:

* `export_traceability_report()` and `traceability_coverage()` for ADRG-ready
  coverage tables.
* `trace_chains()` for multi-step derivation chain tracing with cycle detection.
* `trace_problems()`, a problems-only view that scales to large submissions.

See NEWS.md for the complete list.

## Test environments

* local: Windows 11 x64, R 4.5.x
* GitHub Actions: ubuntu-latest, windows-latest, macos-latest (R release)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

r4subtrace is imported by the r4sub meta-package and suggested by r4subui.
Changes are additive and existing interfaces are unchanged.
