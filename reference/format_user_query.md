# Format a user query for NES completion

Assemble a prompt's user query from a sample's input components (edit
history, variables, code excerpt) according to the chosen edit history
and output formats.

## Usage

``` r
format_user_query(
  input,
  model = "qwen3-8b",
  edit_history_format = c("diffs", "before_after", "narrative"),
  output_format = c("editable_region", "window", "tool_calling", "rewrite_region",
    "rewrite_region_5bt"),
  include_variables = TRUE,
  context_lines = 1L
)
```

## Arguments

- input:

  A list with components `edit_history`, `excerpt`, and `variables`, as
  found in `samples$input[[i]]`.

- model:

  A string identifying the model. Only affects the variables header:
  `"zeta"` uses a shorter header, all other values use a detailed
  header.

- edit_history_format:

  One of `"diffs"`, `"before_after"`, or `"narrative"`.

- output_format:

  One of `"editable_region"`, `"window"`, `"tool_calling"`,
  `"rewrite_region"`, or `"rewrite_region_5bt"`.

- include_variables:

  Logical. Whether to include a variables section.

- context_lines:

  Integer. Number of context lines for `"before_after"` and
  `"narrative"` edit history formats.

## Value

A single character string containing the assembled user query.
