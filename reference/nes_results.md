# Evaluation results

A data frame summarizing evaluation results across all
model/prompt/format configurations stored in `inst/results/`. Each row
is one configuration, with aggregate metrics computed from the
underlying completions and scores.

Regenerate with `source("data-raw/results.R")` after adding or updating
result sets.

## Usage

``` r
nes_results
```

## Format

A data frame with one row per configuration and 11 columns:

- model:

  Character. Model name or identifier.

- prompt:

  Character. System prompt used.

- edit_history:

  Character. Edit history format (`"diffs"`, `"before_after"`, or
  `"narrative"`).

- output_format:

  Character. Output format (`"editable_region"`, `"window"`,
  `"tool_calling"`, `"rewrite_region"`, or `"rewrite_region_5bt"`).

- n_completions:

  Integer. Total number of completions generated. These are all
  multiples of 80; some experimental setups tested across 3 replicates.

- n_processable:

  Integer. Number of completions that produced a response parseable by
  RStudio's NES extension.

- n_exact:

  Integer. Number of exact matches with the target. In this case,
  responses receive a score of 5.

- mean_score:

  Numeric. Mean quality score (0-5) across all completions, where
  non-processable completions score 0.

- median_latency_ms:

  Numeric. Median response latency in milliseconds.

- mean_input_tokens:

  Numeric. Mean input token count.

- mean_output_tokens:

  Numeric. Mean output token count.
