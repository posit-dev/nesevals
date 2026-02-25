# Evaluation samples

`nes_samples` is a data frame of 85 NES evaluation samples, each with a
contiguous target change.

`samples_view()` opens an HTML viewer displaying samples' input excerpts
and target outputs with diff highlighting, along with edit history and
variables. Use the Prev/Next buttons (or left/right arrow keys) to
navigate between samples.

## Usage

``` r
nes_samples

samples_view(x = nes_samples, n = 1L)
```

## Format

A data frame with 85 rows and 4 columns:

- id:

  Character. Sample identifier derived from the source filename.

- input:

  List-column. Each element is a list with components `edit_history`,
  `excerpt`, and `variables`.

- output:

  Character. The target editable region content.

- tags:

  List-column of character vectors.

## Arguments

- x:

  The `nes_samples` data frame.

- n:

  Initial row index to display.

## Value

`x`, invisibly.
