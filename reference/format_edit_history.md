# Format edit history

Convert raw unified-diff edit histories into different text formats for
use in NES prompts.

`format_edit_history()` dispatches to the appropriate format-specific
function. The format-specific functions can also be called directly.

- `format_edit_history_diffs()` returns the raw edit history with a
  standard header.

- `format_edit_history_before_after()` converts each edit into
  before/after code blocks, omitting redundant "Before:" sections when
  they match the previous edit's "After:".

- `format_edit_history_narrative()` produces a natural-language
  description of each edit.

## Usage

``` r
format_edit_history(
  edit_history,
  format = c("diffs", "before_after", "narrative"),
  ...
)

format_edit_history_diffs(edit_history)

format_edit_history_before_after(edit_history, context_lines = 1L)

format_edit_history_narrative(edit_history, context_lines = 1L, fence = "```")
```

## Arguments

- edit_history:

  Character string. The raw unified-diff edit history from a sample's
  input.

- format:

  One of `"diffs"`, `"before_after"`, or `"narrative"`.

- ...:

  Additional arguments passed to the format-specific function.

- context_lines:

  Integer. Number of context lines to retain around changes. Used by
  `"before_after"` and `"narrative"` formats.

## Value

A single character string with the formatted edit history, or `""` if
the input is NULL or empty.
