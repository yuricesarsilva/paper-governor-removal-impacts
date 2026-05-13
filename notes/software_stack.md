# Software Stack Decision

## Main recommendation

- The project should use `R` as the main language.

## Why R is the best fit

- The downstream analysis is likely to rely on the strongest synthetic control ecosystem available in `R`.
- The empirical workflow for state panels, public-finance data, and publication-quality econometric outputs is very natural in `R`.
- `R` has strong support for:
  - synthetic control implementations
  - panel-data preparation
  - data wrangling
  - plotting and reporting
  - direct access to Brazilian public-data packages such as `sidrar`

## Practical implication

- The project should keep one language as the default to avoid fragmented pipelines.
- `Python` can still be used later for very specific extraction tasks if needed, but it should not be the main analytical stack.
- Unless a later bottleneck clearly favors another tool, collection, cleaning, analysis, and visualization should remain in `R`.

## Current implementation choice

- Data-download scripts are being scaffolded in `R`.
- The first download block targets:
  - `PMC`
  - `PMS`
  - `IPCA`
