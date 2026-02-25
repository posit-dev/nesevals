#' Format a user query for NES completion
#'
#' @description
#' Assemble a prompt's user query from a sample's input components (edit history,
#' variables, code excerpt) according to the chosen edit history and output
#' formats.
#'
#' @param input A list with components `edit_history`, `excerpt`, and
#'   `variables`, as found in `samples$input[[i]]`.
#' @param model A string identifying the model. Only affects the variables
#'   header: `"zeta"` uses a shorter header, all other values use a detailed
#'   header.
#' @param edit_history_format One of `"diffs"`, `"before_after"`, or
#'   `"narrative"`.
#' @param output_format One of `"editable_region"`, `"window"`,
#'   `"tool_calling"`, `"rewrite_region"`, or `"rewrite_region_5bt"`.
#' @param include_variables Logical. Whether to include a variables section.
#' @param context_lines Integer. Number of context lines for `"before_after"`
#'   and `"narrative"` edit history formats.
#'
#' @returns A single character string containing the assembled user query.
#' @export
format_user_query <- function(
  input,
  model = "qwen3-8b",
  edit_history_format = c("diffs", "before_after", "narrative"),
  output_format = c(
    "editable_region",
    "window",
    "tool_calling",
    "rewrite_region",
    "rewrite_region_5bt"
  ),
  include_variables = TRUE,
  context_lines = 1L
) {
  edit_history_format <- match.arg(edit_history_format)
  output_format <- match.arg(output_format)

  edit_history_args <- list(
    edit_history = input$edit_history,
    format = edit_history_format
  )
  if (edit_history_format %in% c("before_after", "narrative")) {
    edit_history_args$context_lines <- context_lines
  }
  if (
    edit_history_format == "narrative" && output_format == "rewrite_region_5bt"
  ) {
    edit_history_args$fence <- "`````"
  }
  edit_history_section <- do.call(format_edit_history, edit_history_args)

  if (output_format %in% c("window", "rewrite_region", "rewrite_region_5bt")) {
    edit_history_section <- gsub(
      "<|user_cursor_is_here|>",
      "<cursor>",
      edit_history_section,
      fixed = TRUE
    )
  }

  variables_section <- if (include_variables) {
    format_variables(input$variables)
  } else {
    ""
  }

  variables_with_header <- ""
  if (nzchar(variables_section)) {
    variables_header <- if (model != "zeta") {
      "## Variables\n\nThe following variables are present in the user's computational environment:\n\n"
    } else {
      "## Variables\n\n"
    }
    variables_with_header <- paste0(variables_header, variables_section)
  }

  if (output_format %in% c("rewrite_region", "rewrite_region_5bt")) {
    fence <- if (output_format == "rewrite_region_5bt") "`````" else "```"
    context_section <- convert_excerpt_to_window(
      input$excerpt,
      cursor = "replace",
      fence = fence
    )
    editable_section <- convert_editable_region_to_window(
      input$excerpt,
      cursor = "replace",
      fence = fence
    )
    parts <- c(
      paste0(
        "## File context\n\n",
        "Here is the code the user is currently editing.\n\n",
        context_section
      )
    )
    if (nzchar(edit_history_section)) {
      edit_history_section <- sub(
        "## Edit History\n\n",
        "## Edit History\n\nThe following edits led to the current state of the file.\n\n",
        edit_history_section,
        fixed = TRUE
      )
      parts <- c(parts, edit_history_section)
    }
    if (nzchar(variables_with_header)) {
      parts <- c(parts, variables_with_header)
    }
    parts <- c(
      parts,
      paste0(
        "## Region\n\n",
        "Rewrite the following region from the excerpt above ",
        "to predict the user's next edit:\n\n",
        editable_section
      )
    )
  } else if (output_format == "tool_calling") {
    context_section <- convert_excerpt_to_window(
      input$excerpt,
      cursor = "keep"
    )
    editable_section <- convert_editable_region_to_window(
      input$excerpt,
      cursor = "keep"
    )
    parts <- character()
    if (nzchar(edit_history_section)) {
      parts <- c(parts, edit_history_section)
    }
    if (nzchar(variables_with_header)) {
      parts <- c(parts, variables_with_header)
    }
    parts <- c(
      parts,
      paste0(
        "## File context\n\n",
        "Here's a longer excerpt from the active document, ",
        "which might demonstrate useful patterns.\n\n",
        context_section
      ),
      paste0(
        "## Code\n\n",
        "Given the available context, predict the user's next edit ",
        "to the following code:\n\n",
        editable_section
      )
    )
  } else {
    parts <- character()
    if (nzchar(edit_history_section)) {
      parts <- c(parts, edit_history_section)
    }
    if (nzchar(variables_with_header)) {
      parts <- c(parts, variables_with_header)
    }
    if (output_format == "window") {
      code_section <- convert_excerpt_to_window(input$excerpt)
      parts <- c(
        parts,
        paste0(
          "## Code\n\n",
          "Given the available context, rewrite the excerpt ",
          "to predict the user's next edit:\n\n",
          code_section
        )
      )
    } else {
      parts <- c(parts, paste0("## Code\n\n", input$excerpt))
    }
  }

  paste(parts, collapse = "\n\n")
}

#' Format variables for a prompt
#'
#' @param variables A character vector or list of variables from a sample's
#'   input.
#'
#' @returns A single character string with one variable per line, or `""` if
#'   the input is NULL or empty.
#' @export
format_variables <- function(variables) {
  if (is.null(variables) || length(variables) == 0L) {
    return("")
  }

  if (is.character(variables)) {
    return(paste(variables, collapse = "\n"))
  }

  parts <- vapply(
    variables,
    function(v) {
      if (is.character(v)) {
        return(v)
      }
      name <- if (is.null(v$name)) "" else v$name
      type <- if (is.null(v$type)) "" else v$type
      if (!is.null(v$value) && nzchar(v$value)) {
        sprintf("%s: <%s>\n  %s", name, type, v$value)
      } else {
        sprintf("%s: <%s>", name, type)
      }
    },
    character(1)
  )

  paste(parts, collapse = "\n")
}

convert_excerpt_to_window <- function(
  excerpt,
  cursor = c("replace", "keep"),
  fence = "```"
) {
  cursor <- match.arg(cursor)
  filename <- extract_filename_from_excerpt(excerpt)

  content <- excerpt
  content <- sub("^```[a-zA-Z0-9_./-]*\n?", "", content)
  content <- sub("\n?```\\s*$", "", content)
  content <- gsub("<\\|editable_region_start\\|>\n?", "", content)
  content <- gsub("\n?<\\|editable_region_end\\|>", "", content)

  if (cursor == "replace") {
    content <- gsub("<\\|user_cursor_is_here\\|>", "<cursor>", content)
  }

  paste0(fence, filename, "\n", content, "\n", fence)
}

convert_editable_region_to_window <- function(
  excerpt,
  cursor = c("replace", "keep"),
  fence = "```"
) {
  cursor <- match.arg(cursor)
  filename <- extract_filename_from_excerpt(excerpt)
  region <- extract_region_text(excerpt)
  if (cursor == "replace") {
    region <- gsub("<\\|user_cursor_is_here\\|>", "<cursor>", region)
  }
  paste0(fence, filename, "\n", region, "\n", fence)
}

extract_filename_from_excerpt <- function(excerpt) {
  match <- regmatches(excerpt, regexpr("^```([a-zA-Z0-9_./-]+)", excerpt))
  if (length(match) > 0L) {
    sub("^```", "", match)
  } else {
    "file.txt"
  }
}

format_request_body <- function(
  system_prompt,
  user_content,
  model,
  output_format = "editable_region"
) {
  if (model == "zeta") {
    return(list(
      prompt = paste(system_prompt, user_content, sep = "\n\n"),
      max_tokens = 500L,
      min_tokens = 3L
    ))
  }

  body <- list(
    messages = list(
      list(role = "system", content = system_prompt),
      list(role = "user", content = user_content)
    ),
    max_tokens = 500L,
    temperature = 0.2,
    chat_template_kwargs = list(enable_thinking = FALSE)
  )

  if (output_format == "tool_calling") {
    body$tools <- list(edit_tool_definition())
    body$tool_choice <- "auto"
  }

  body
}

edit_tool_definition <- function() {
  list(
    type = "function",
    `function` = list(
      name = "edit",
      description = "Propose an edit to the code excerpt.",
      parameters = list(
        type = "object",
        properties = list(
          old = list(
            type = "string",
            description = "The exact text to replace."
          ),
          new = list(
            type = "string",
            description = "The text to replace it with."
          )
        ),
        required = list("old", "new")
      )
    )
  )
}
