# Grade NES completions

Score completions against target outputs using a multi-tiered system:

1.  **Processability**: Is the response non-`NA` and non-empty?

2.  **Exact match**: Does the response exactly match the target? If so,
    score 5 without an LLM call.

3.  **LLM quality grading**: For non-exact-match processable
    completions, an LLM judge scores the completion on a 0–5 scale.

## Usage

``` r
completions_grade(
  completions,
  samples,
  name = attr(completions, "name"),
  max_active = 5L
)
```

## Arguments

- completions:

  A data frame as returned by
  [`completions_generate()`](https://posit-dev.github.io/nesevals/reference/completions_generate.md)
  or
  [`completions_read()`](https://posit-dev.github.io/nesevals/reference/completions_read.md),
  with at least columns `sample_id`, `replicate`, and `response`.

- samples:

  A data frame of evaluation samples in the same format as
  [nes_samples](https://posit-dev.github.io/nesevals/reference/nes_samples.md).
  Must contain all `sample_id` values present in `completions`.

- name:

  Character. Name for the saved scores file. Defaults to the `"name"`
  attribute of `completions` (set automatically by
  [`completions_generate()`](https://posit-dev.github.io/nesevals/reference/completions_generate.md)
  and
  [`completions_read()`](https://posit-dev.github.io/nesevals/reference/completions_read.md)).
  If `NULL`, scores are not saved to disk.

- max_active:

  Integer. Maximum number of simultaneous LLM grading requests.

## Value

A data frame with columns `sample_id`, `replicate`, `processable`,
`exact_match`, `score` (integer, 0–5), `reasoning` (character), and
`tags` (list-column of character vectors).
