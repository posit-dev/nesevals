# Generate completions from NES model endpoints

Send evaluation samples to a model endpoint and collect completions
along with response latency. Results are written to JSON files under
`inst/results/completions/` and `inst/results/metadata/`.

## Usage

``` r
completions_generate(
  samples,
  model = c("qwen3-8b", "zeta"),
  prompt = c("zeta-supercomplete", "qwen-supercomplete", "rewrite-window",
    "tool-calling", "rewrite-region", "rewrite-region-5bt"),
  edit_history_format = c("diffs", "before_after", "narrative"),
  output_format = c("editable_region", "window", "tool_calling", "rewrite_region",
    "rewrite_region_5bt"),
  include_variables = TRUE,
  n_replicates = 1L,
  context_lines = 1L,
  results_dir = NULL
)
```

## Arguments

- samples:

  A data frame of evaluation samples in the same format as
  [nes_samples](https://posit-dev.github.io/nesevals/reference/nes_samples.md).

- model:

  Either a string naming a Baseten model (`"qwen3-8b"` or `"zeta"`) or
  an ellmer
  [ellmer::Chat](https://ellmer.tidyverse.org/reference/Chat.html)
  object (e.g. from
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)
  or
  [`ellmer::chat_claude()`](https://ellmer.tidyverse.org/reference/chat_anthropic.html)).
  When a Chat object is provided, the model name is derived from
  `chat$get_model()`. The `"tool_calling"` output format is not
  supported with Chat objects.

- prompt:

  One of `"zeta-supercomplete"`, `"qwen-supercomplete"`,
  `"rewrite-window"`, `"tool-calling"`, or `"rewrite-region"`.
  Determines which system prompt file to use from `inst/prompts/`.

- edit_history_format:

  One of `"diffs"`, `"before_after"`, or `"narrative"`.

- output_format:

  One of `"editable_region"`, `"window"`, `"tool_calling"`, or
  `"rewrite_region"`.

- include_variables:

  Logical. Whether to include variables in the prompt.

- n_replicates:

  Integer. Number of completions to generate per sample.

- context_lines:

  Integer. Number of context lines for before/after and narrative edit
  history formats.

- results_dir:

  Directory where results are stored. When `NULL` (the default), falls
  back to `getOption("nesevals.results_dir")`, then `inst/results/`
  inside the package source tree, then `nesevals-results/` in the
  current working directory.

## Value

Invisibly, a data frame with columns `sample_id`, `replicate`,
`response` (character), `latency` (numeric, in seconds), `tokens_input`
(integer), `tokens_output` (integer), and `request` (list-column
containing the request body).
