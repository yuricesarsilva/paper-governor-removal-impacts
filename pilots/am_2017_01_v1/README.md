# RR 2018-01 Pilot V5

This folder contains a clean rebuild of the Roraima 2018 pilot under the current three-block article design.

## Core principles

- Built from scratch rather than copied from an earlier pilot.
- Uses the V5 smoothing rule: complete trailing windows through -1, event coded as 0, and first post-treatment moving average at +1.
- Keeps the main post-treatment window inside 2019 to avoid pandemic overlap and the CAGED methodology break.

## Scripts

1. `code/01_build_am_2017_01_v1_panels.R`
2. `code/02_run_am_2017_01_v1_scm.R`
3. `code/03b_make_am_2017_01_v1_report_figures.R`
4. `code/03_make_am_2017_01_v1_report.R`
