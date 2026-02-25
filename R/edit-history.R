#' Format edit history
#'
#' @description
#' Convert raw unified-diff edit histories into different text formats for
#' use in NES prompts.
#'
#' `format_edit_history()` dispatches to the appropriate format-specific
#' function. The format-specific functions can also be called directly.
#'
#' * `format_edit_history_diffs()` returns the raw edit history with a
#'   standard header.
#' * `format_edit_history_before_after()` converts each edit into
#'   before/after code blocks, omitting redundant "Before:" sections when
#'   they match the previous edit's "After:".
#' * `format_edit_history_narrative()` produces a natural-language
#'   description of each edit.
#'
#' @param edit_history Character string. The raw unified-diff edit history
#'   from a sample's input.
#' @param format One of `"diffs"`, `"before_after"`, or `"narrative"`.
#' @param context_lines Integer. Number of context lines to retain around
#'   changes. Used by `"before_after"` and `"narrative"` formats.
#' @param ... Additional arguments passed to the format-specific function.
#'
#' @returns A single character string with the formatted edit history, or
#'   `""` if the input is NULL or empty.
#'
#' @export
#' @rdname format_edit_history
format_edit_history <- function(
  edit_history,
  format = c("diffs", "before_after", "narrative"),
  ...
) {
  format <- match.arg(format)
  switch(
    format,
    diffs = format_edit_history_diffs(edit_history, ...),
    before_after = format_edit_history_before_after(edit_history, ...),
    narrative = format_edit_history_narrative(edit_history, ...)
  )
}

#' @export
#' @rdname format_edit_history
format_edit_history_diffs <- function(edit_history) {
  if (is.null(edit_history) || !nzchar(edit_history)) {
    return("")
  }

  text <- strip_edit_history_header(edit_history)
  blocks <- strsplit(text, "\n\nEdit ")[[1]]

  formatted <- vapply(
    seq_along(blocks),
    function(i) {
      block <- blocks[[i]]
      if (i == 1L) {
        block <- sub("^Edit ", "", block)
      }
      lines <- strsplit(block, "\n")[[1]]

      filename <- trimws(lines[2])
      filename <- sub("^```", "", filename)
      filename <- sub("```$", "", filename)

      hunk_idx <- which(grepl("^@@", lines))[1]
      if (is.na(hunk_idx)) {
        return("")
      }

      diff_lines <- lines[hunk_idx:length(lines)]
      diff_lines <- diff_lines[!grepl("^```$", diff_lines)]

      paste0("```", filename, "\n", paste(diff_lines, collapse = "\n"), "\n```")
    },
    character(1)
  )

  formatted <- formatted[nzchar(formatted)]

  paste0(
    "## Edit History\n\n",
    "The following are the latest edits made by the user, ",
    "from earlier to later.\n\n",
    paste(formatted, collapse = "\n\n")
  )
}

#' @export
#' @rdname format_edit_history
format_edit_history_before_after <- function(edit_history, context_lines = 1L) {
  if (is.null(edit_history) || !nzchar(edit_history)) {
    return("")
  }

  edits <- parse_edit_history(edit_history)
  if (length(edits) == 0L) {
    return("")
  }

  result_parts <- "## Edit History\n\nEdits are in least-to-most recent order."
  prev_after <- NULL
  prev_before <- NULL

  for (edit in edits) {
    trimmed <- trim_to_context(edit$parsed_lines, context_lines)
    before <- before_lines(trimmed)
    after <- after_lines(trimmed)

    before_str <- paste(before, collapse = "\n")
    after_str <- paste(after, collapse = "\n")

    skip_before <- !is.null(prev_after) &&
      (before_str == prev_after || before_str == prev_before)

    if (skip_before) {
      edit_section <- paste0(
        "\n### Edit ",
        edit$edit_num,
        ":\n\n",
        "After:\n\n```\n",
        after_str,
        "\n```"
      )
    } else {
      edit_section <- paste0(
        "\n### Edit ",
        edit$edit_num,
        ":\n\n",
        "Before:\n\n```\n",
        before_str,
        "\n```\n\n",
        "After:\n\n```\n",
        after_str,
        "\n```"
      )
    }

    prev_after <- after_str
    prev_before <- before_str
    result_parts <- c(result_parts, edit_section)
  }

  paste(result_parts, collapse = "\n")
}

#' @export
#' @rdname format_edit_history
format_edit_history_narrative <- function(
  edit_history,
  context_lines = 1L,
  fence = "```"
) {
  if (is.null(edit_history) || !nzchar(edit_history)) {
    return("")
  }

  edits <- parse_edit_history(edit_history)
  if (length(edits) == 0L) {
    return("")
  }

  n_edits <- length(edits)
  parts <- character()
  prev_before <- NULL
  prev_added <- NULL

  for (i in seq_along(edits)) {
    edit <- edits[[i]]
    trimmed <- trim_to_context(edit$parsed_lines, context_lines)
    before <- before_lines(trimmed)
    after <- after_lines(trimmed)

    before_str <- paste(before, collapse = "\n")
    after_str <- paste(after, collapse = "\n")

    removed <- vapply(
      trimmed[vapply(trimmed, \(x) x$type == "removed", logical(1))],
      \(x) x$text,
      character(1)
    )
    added <- vapply(
      trimmed[vapply(trimmed, \(x) x$type == "added", logical(1))],
      \(x) x$text,
      character(1)
    )

    if (!is.null(prev_before) && before_str == prev_before) {
      desc <- describe_edit(
        trimws(prev_added, which = "left"),
        trimws(added, which = "left")
      )
    } else {
      desc <- describe_edit(
        trimws(removed, which = "left"),
        trimws(added, which = "left")
      )
    }
    is_last <- i == n_edits

    if (i == 1L) {
      part <- paste0(
        "The user's code started like this:\n\n",
        fence,
        "\n",
        before_str,
        "\n",
        fence,
        "\n\n"
      )

      if (is_last) {
        part <- paste0(
          part,
          "Most recently, the user ",
          desc,
          ":\n\n",
          fence,
          "\n",
          after_str,
          "\n",
          fence
        )
      } else {
        part <- paste0(
          part,
          "Then, the user ",
          desc,
          ":\n\n",
          fence,
          "\n",
          after_str,
          "\n",
          fence
        )
      }
    } else if (is_last) {
      part <- paste0(
        "Most recently, the user ",
        desc,
        ":\n\n",
        fence,
        "\n",
        after_str,
        "\n",
        fence
      )
    } else {
      part <- paste0(
        "Then, the user ",
        desc,
        ":\n\n",
        fence,
        "\n",
        after_str,
        "\n",
        fence
      )
    }

    prev_before <- before_str
    prev_added <- added
    parts <- c(parts, part)
  }

  paste0("## Edit History\n\n", paste(parts, collapse = "\n\n"))
}

strip_edit_history_header <- function(edit_history) {
  text <- sub("^## Edit History\n+", "", edit_history)
  sub(
    "^The following are the latest edits made by the user[^\n]*\n+",
    "",
    text
  )
}

parse_edit_history <- function(edit_history) {
  text <- strip_edit_history_header(edit_history)

  edit_blocks <- strsplit(text, "\n\nEdit ")[[1]]
  if (length(edit_blocks) == 0L) {
    return(list())
  }

  lapply(seq_along(edit_blocks), function(i) {
    block <- edit_blocks[[i]]
    if (i == 1L) {
      block <- sub("^Edit ", "", block)
    }
    parse_edit_block(block)
  })
}

parse_edit_block <- function(block) {
  lines <- strsplit(block, "\n")[[1]]

  header <- lines[1]
  edit_num <- sub(" \\(.*", "", header)
  timestamp_match <- regmatches(header, regexpr("\\(([^)]+)\\)", header))
  timestamp <- gsub("[()]", "", timestamp_match)

  diff_start <- which(grepl("^@@", lines))
  if (length(diff_start) == 0L) {
    return(list(
      edit_num = edit_num,
      timestamp = timestamp,
      filename = "",
      parsed_lines = list()
    ))
  }

  filename_lines <- lines[2:(diff_start[1] - 1)]
  filename <- trimws(filename_lines[1])
  filename <- sub("^```", "", filename)
  filename <- sub("```$", "", filename)

  diff_lines <- lines[(diff_start[1] + 1):length(lines)]
  diff_lines <- diff_lines[!grepl("^```$", diff_lines)]

  parsed_lines <- list()
  for (line in diff_lines) {
    if (grepl("^-", line)) {
      parsed_lines[[length(parsed_lines) + 1]] <- list(
        type = "removed",
        text = sub("^-", "", line)
      )
    } else if (grepl("^\\+", line)) {
      parsed_lines[[length(parsed_lines) + 1]] <- list(
        type = "added",
        text = sub("^\\+", "", line)
      )
    } else if (grepl("^ ", line)) {
      parsed_lines[[length(parsed_lines) + 1]] <- list(
        type = "context",
        text = sub("^ ", "", line)
      )
    }
  }

  list(
    edit_num = edit_num,
    timestamp = timestamp,
    filename = filename,
    parsed_lines = parsed_lines
  )
}

trim_to_context <- function(parsed_lines, context_lines) {
  if (length(parsed_lines) == 0L) {
    return(parsed_lines)
  }

  is_change <- vapply(
    parsed_lines,
    \(x) x$type %in% c("added", "removed"),
    logical(1)
  )
  change_indices <- which(is_change)

  if (length(change_indices) == 0L) {
    return(parsed_lines)
  }

  first_change <- min(change_indices)
  last_change <- max(change_indices)
  keep_start <- max(1L, first_change - context_lines)
  keep_end <- min(length(parsed_lines), last_change + context_lines)

  parsed_lines[keep_start:keep_end]
}

before_lines <- function(trimmed) {
  vapply(
    trimmed[vapply(trimmed, \(x) x$type != "added", logical(1))],
    \(x) x$text,
    character(1)
  )
}

after_lines <- function(trimmed) {
  vapply(
    trimmed[vapply(trimmed, \(x) x$type != "removed", logical(1))],
    \(x) x$text,
    character(1)
  )
}

describe_edit <- function(removed, added) {
  n_removed <- length(removed)
  n_added <- length(added)

  if (n_removed == 0L && n_added == 0L) {
    return("made no changes")
  }

  if (n_removed == 1L && n_added == 1L) {
    old <- removed[1]
    new <- added[1]

    if (startsWith(new, old)) {
      delta <- substr(new, nchar(old) + 1L, nchar(new))
      return(paste0("typed `", delta, "`"))
    }

    if (startsWith(old, new)) {
      delta <- substr(old, nchar(new) + 1L, nchar(old))
      return(paste0("removed `", delta, "` from the end"))
    }

    return(paste0("changed `", old, "` to `", new, "`"))
  }

  if (n_removed == 0L && n_added == 1L) {
    return(paste0("added `", added[1], "`"))
  }

  if (n_removed == 1L && n_added == 0L) {
    return(paste0("removed `", removed[1], "`"))
  }

  if (n_removed > 0L && n_added > 0L) {
    return(paste0(
      "added ",
      n_added,
      " line",
      if (n_added != 1L) "s",
      " and removed ",
      n_removed,
      " line",
      if (n_removed != 1L) "s"
    ))
  }

  if (n_added > 0L) {
    return(paste0("added ", n_added, " line", if (n_added != 1L) "s"))
  }

  paste0("removed ", n_removed, " line", if (n_removed != 1L) "s")
}
