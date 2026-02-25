#' Evaluation samples
#'
#' @description
#' `nes_samples` is a data frame of 85 NES evaluation samples, each with a
#' contiguous target change.
#'
#' `samples_view()` opens an HTML viewer displaying samples' input excerpts
#' and target outputs with diff highlighting, along with edit history and
#' variables. Use the Prev/Next buttons (or left/right arrow keys) to
#' navigate between samples.
#'
#' @format A data frame with 85 rows and 4 columns:
#' \describe{
#'   \item{id}{Character. Sample identifier derived from the source filename.}
#'   \item{input}{List-column. Each element is a list with components
#'     `edit_history`, `excerpt`, and `variables`.}
#'   \item{output}{Character. The target editable region content.}
#'   \item{tags}{List-column of character vectors.}
#' }
#'
#' @param x The `nes_samples` data frame.
#' @param n Initial row index to display.
#' @returns `x`, invisibly.
#'
#' @rdname nes_samples
"nes_samples"

#' @export
#' @rdname nes_samples
samples_view <- function(x = nes_samples, n = 1L) {
  n <- as.integer(n)
  if (n < 1L || n > nrow(x)) {
    cli::cli_abort("{.arg n} must be between 1 and {nrow(x)}.")
  }

  sample_divs <- vapply(
    seq_len(nrow(x)),
    function(i) render_sample_div(x[i, ], i),
    character(1)
  )

  html <- build_navigable_html(sample_divs, n)
  print(htmltools::browsable(html))
  invisible(x)
}

render_sample_div <- function(row, i) {
  input <- row$input[[1]]
  output_text <- row$output
  tags <- if (is.null(row$tags[[1]])) character() else row$tags[[1]]

  excerpt <- input$excerpt
  edit_history <- if (is.null(input$edit_history)) "" else input$edit_history
  variables <- input$variables

  parts <- parse_excerpt(excerpt)
  output_region <- extract_region_text(output_text)

  input_region_clean <- gsub("<\\|user_cursor_is_here\\|>", "", parts$editable)
  input_lines <- strsplit(input_region_clean, "\n")[[1]]
  output_lines <- strsplit(output_region, "\n")[[1]]
  status <- compute_line_status(input_lines, output_lines)

  input_display_lines <- strsplit(parts$editable, "\n")[[1]]

  build_sample_html(
    parts = parts,
    input_display_lines = input_display_lines,
    input_status = status$a_status,
    output_lines = output_lines,
    output_status = status$b_status,
    edit_history = edit_history,
    variables = variables,
    tags = tags,
    n = i
  )
}

parse_excerpt <- function(excerpt) {
  start_marker <- "<|editable_region_start|>"
  end_marker <- "<|editable_region_end|>"

  start_pos <- regexpr(start_marker, excerpt, fixed = TRUE)
  end_pos <- regexpr(end_marker, excerpt, fixed = TRUE)

  if (start_pos == -1 || end_pos == -1) {
    return(list(prefix = excerpt, editable = "", suffix = ""))
  }

  prefix <- substr(excerpt, 1, start_pos - 1)
  editable <- substr(excerpt, start_pos + nchar(start_marker), end_pos - 1)
  suffix <- substr(excerpt, end_pos + nchar(end_marker), nchar(excerpt))

  editable <- sub("^\n", "", editable)
  editable <- sub("\n$", "", editable)

  list(prefix = prefix, editable = editable, suffix = suffix)
}

extract_region_text <- function(text) {
  start_marker <- "<|editable_region_start|>"
  end_marker <- "<|editable_region_end|>"

  start_pos <- regexpr(start_marker, text, fixed = TRUE)
  end_pos <- regexpr(end_marker, text, fixed = TRUE)

  if (start_pos == -1 || end_pos == -1) {
    return(text)
  }

  region <- substr(text, start_pos + nchar(start_marker), end_pos - 1)
  region <- sub("^\n", "", region)
  region <- sub("\n$", "", region)
  region
}

compute_line_status <- function(a, b) {
  n <- length(a)
  m <- length(b)

  if (n == 0 && m == 0) {
    return(list(a_status = character(), b_status = character()))
  }
  if (n == 0) {
    return(list(a_status = character(), b_status = rep("added", m)))
  }
  if (m == 0) {
    return(list(a_status = rep("removed", n), b_status = character()))
  }

  dp <- matrix(0L, nrow = n + 1, ncol = m + 1)
  for (i in seq_len(n)) {
    for (j in seq_len(m)) {
      if (a[i] == b[j]) {
        dp[i + 1, j + 1] <- dp[i, j] + 1L
      } else {
        dp[i + 1, j + 1] <- max(dp[i, j + 1], dp[i + 1, j])
      }
    }
  }

  a_status <- rep("removed", n)
  b_status <- rep("added", m)
  i <- n
  j <- m
  while (i > 0 && j > 0) {
    if (a[i] == b[j]) {
      a_status[i] <- "equal"
      b_status[j] <- "equal"
      i <- i - 1
      j <- j - 1
    } else if (dp[i, j + 1] >= dp[i + 1, j]) {
      i <- i - 1
    } else {
      j <- j - 1
    }
  }

  list(a_status = a_status, b_status = b_status)
}

render_diff_lines <- function(lines, statuses, style_cursor = FALSE) {
  if (length(lines) == 0) {
    return("")
  }

  cursor_esc <- htmltools::htmlEscape("<|user_cursor_is_here|>")
  cursor_styled <- paste0('<span class="marker">', cursor_esc, "</span>")

  rendered <- vapply(
    seq_along(lines),
    function(i) {
      escaped <- htmltools::htmlEscape(lines[i])
      if (style_cursor) {
        escaped <- gsub(cursor_esc, cursor_styled, escaped, fixed = TRUE)
      }
      switch(
        statuses[i],
        removed = paste0('<span class="diff-removed">', escaped, "</span>"),
        added = paste0('<span class="diff-added">', escaped, "</span>"),
        escaped
      )
    },
    character(1)
  )

  paste(rendered, collapse = "\n")
}

render_variables_html <- function(variables) {
  if (is.null(variables) || length(variables) == 0) {
    return('<span style="color: #999;">None</span>')
  }

  rows <- vapply(
    variables,
    function(v) {
      if (is.atomic(v)) {
        return(paste0(
          "<tr><td colspan='3'>",
          htmltools::htmlEscape(v),
          "</td></tr>"
        ))
      }
      name <- htmltools::htmlEscape(if (is.null(v$name)) "" else v$name)
      type <- htmltools::htmlEscape(if (is.null(v$type)) "" else v$type)
      value <- if (is.null(v$value)) "" else v$value
      if (nzchar(value)) {
        value <- htmltools::htmlEscape(substr(value, 1, 200))
        paste0(
          "<tr><td><strong>",
          name,
          "</strong></td><td>",
          type,
          "</td>",
          '<td class="var-value">',
          value,
          "</td></tr>"
        )
      } else {
        paste0(
          "<tr><td><strong>",
          name,
          "</strong></td><td>",
          type,
          "</td><td></td></tr>"
        )
      }
    },
    character(1)
  )

  paste0(
    "<table><thead><tr><th>Name</th><th>Type</th><th>Value</th></tr></thead><tbody>",
    paste(rows, collapse = ""),
    "</tbody></table>"
  )
}

build_sample_html <- function(
  parts,
  input_display_lines,
  input_status,
  output_lines,
  output_status,
  edit_history,
  variables,
  tags,
  n
) {
  marker_start <- paste0(
    '<span class="marker">',
    htmltools::htmlEscape("<|editable_region_start|>"),
    "</span>"
  )
  marker_end <- paste0(
    '<span class="marker">',
    htmltools::htmlEscape("<|editable_region_end|>"),
    "</span>"
  )

  input_region_html <- render_diff_lines(
    input_display_lines,
    input_status,
    style_cursor = TRUE
  )
  input_pre <- paste0(
    '<span class="dimmed">',
    htmltools::htmlEscape(parts$prefix),
    "</span>",
    marker_start,
    "\n",
    input_region_html,
    "\n",
    marker_end,
    '<span class="dimmed">',
    htmltools::htmlEscape(parts$suffix),
    "</span>"
  )

  output_region_html <- render_diff_lines(output_lines, output_status)
  output_pre <- paste0(
    marker_start,
    "\n",
    output_region_html,
    "\n",
    marker_end
  )

  edit_history_html <- if (nzchar(edit_history)) {
    htmltools::htmlEscape(edit_history)
  } else {
    '<span style="color: #999;">None</span>'
  }

  vars_html <- render_variables_html(variables)

  tags_html <- if (length(tags) > 0) {
    paste(
      vapply(
        tags,
        function(t) {
          paste0('<span class="tag">', htmltools::htmlEscape(t), "</span>")
        },
        character(1)
      ),
      collapse = " "
    )
  } else {
    ""
  }

  paste0(
    '<div class="sample" id="sample-',
    n,
    '" style="display:none;">',
    '<div class="tags">',
    tags_html,
    "</div>",
    '<div class="panels">',
    '<div class="panel"><h3>Input</h3><pre class="code-box">',
    input_pre,
    "</pre></div>",
    '<div class="panel"><h3>Target</h3><pre class="code-box">',
    output_pre,
    "</pre></div>",
    "</div>",
    '<div class="panels">',
    '<div class="panel"><h3>Edit History</h3><pre class="code-box">',
    edit_history_html,
    "</pre></div>",
    '<div class="panel"><h3>Variables</h3><div class="code-box">',
    vars_html,
    "</div></div>",
    "</div>",
    "</div>"
  )
}

build_navigable_html <- function(sample_divs, initial_n) {
  total <- length(sample_divs)
  htmltools::HTML(paste0(
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>",
    viewer_css(),
    "</style></head><body>",
    '<div class="nav-bar">',
    '<button onclick="navigate(-1)">&larr; Prev</button>',
    '<span id="counter">Sample ',
    initial_n,
    " / ",
    total,
    "</span>",
    '<button onclick="navigate(1)">Next &rarr;</button>',
    "</div>",
    paste(sample_divs, collapse = "\n"),
    "<script>",
    "var current = ",
    initial_n,
    ", total = ",
    total,
    ";",
    "function show(n) {",
    "  document.querySelectorAll('.sample').forEach(function(d){d.style.display='none';});",
    "  document.getElementById('sample-'+n).style.display='block';",
    "  document.getElementById('counter').textContent='Sample '+n+' / '+total;",
    "}",
    "function navigate(delta) {",
    "  current += delta;",
    "  if (current < 1) current = total;",
    "  if (current > total) current = 1;",
    "  show(current);",
    "}",
    "document.addEventListener('keydown', function(e) {",
    "  if (e.key === 'ArrowLeft') navigate(-1);",
    "  if (e.key === 'ArrowRight') navigate(1);",
    "});",
    "show(current);",
    "</script>",
    "</body></html>"
  ))
}

viewer_css <- function() {
  paste0(
    "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', ",
    "sans-serif; margin: 20px; background: #fff; } ",
    ".tags { margin-bottom: 12px; } ",
    ".tag { display: inline-block; background: #e1e4e8; border-radius: 12px; ",
    "padding: 2px 10px; font-size: 0.85em; margin-right: 4px; color: #24292e; } ",
    ".panels { display: flex; gap: 16px; margin-bottom: 16px; } ",
    ".panel { flex: 1; min-width: 0; } ",
    ".panel h3 { margin: 0 0 8px 0; font-size: 1em; } ",
    ".code-box { background-color: #f6f8fa; border: 1px solid #d0d7de; ",
    "border-radius: 6px; padding: 16px; ",
    "font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace; ",
    "font-size: 0.85em; white-space: pre-wrap; word-wrap: break-word; ",
    "max-height: 400px; overflow-y: auto; } ",
    "pre.code-box { margin: 0; } ",
    ".dimmed { opacity: 0.5; } ",
    ".diff-removed { background-color: #ffebe9; color: #82071e; } ",
    ".diff-added { background-color: #dafbe1; color: #116329; } ",
    ".marker { color: #8b5cf6; font-weight: bold; } ",
    "table { width: 100%; border-collapse: collapse; } ",
    "th, td { text-align: left; padding: 4px 8px; ",
    "border-bottom: 1px solid #d0d7de; } ",
    "th { font-weight: 600; } ",
    ".var-value { color: #666; font-size: 0.9em; } ",
    ".nav-bar { display: flex; align-items: center; gap: 16px; ",
    "margin-bottom: 16px; position: sticky; top: 0; background: #fff; ",
    "padding: 12px 0; border-bottom: 1px solid #d0d7de; z-index: 10; } ",
    ".nav-bar button { padding: 6px 16px; border: 1px solid #d0d7de; ",
    "border-radius: 6px; background: #f6f8fa; cursor: pointer; ",
    "font-size: 0.9em; } ",
    ".nav-bar button:hover { background: #e1e4e8; } ",
    "#counter { font-weight: 600; }"
  )
}
