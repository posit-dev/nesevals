# Read saved completions

Load a previously saved completions result set from
`inst/results/completions/`.

## Usage

``` r
completions_read(name)
```

## Arguments

- name:

  The name of the result set, e.g.
  `"qwen3-8b_diffs_editable-region_zeta-supercomplete"`. This
  corresponds to the filename (without `.json`) under
  `inst/results/completions/`.

## Value

A data frame with columns `sample_id`, `replicate`, `response`,
`latency`, `tokens_input`, and `tokens_output`.
