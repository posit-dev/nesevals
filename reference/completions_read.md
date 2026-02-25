# Read saved completions

Load a previously saved completions result set from
`inst/results/completions/`.

## Usage

``` r
completions_read(name, results_dir = NULL)
```

## Arguments

- name:

  The name of the result set, e.g.
  `"qwen3-8b_diffs_editable-region_zeta-supercomplete"`. This
  corresponds to the filename (without `.json`) under
  `inst/results/completions/`.

- results_dir:

  Directory where results are stored. When `NULL` (the default), falls
  back to `getOption("nesevals.results_dir")`, then `inst/results/`
  inside the package source tree, then `nesevals-results/` in the
  current working directory.

## Value

A data frame with columns `sample_id`, `replicate`, `response`,
`latency`, `tokens_input`, and `tokens_output`.
