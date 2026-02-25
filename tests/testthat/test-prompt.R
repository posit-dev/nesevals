test_that("format_variables joins character vectors", {
  vars <- c("x: <numeric>", "df: <data.frame>")
  expect_equal(format_variables(vars), "x: <numeric>\ndf: <data.frame>")
})

test_that("format_variables returns empty string for NULL", {
  expect_equal(format_variables(NULL), "")
})

test_that("format_variables returns empty string for empty vector", {
  expect_equal(format_variables(character()), "")
})

test_that("format_variables handles list format", {
  vars <- list(
    list(name = "x", type = "numeric", value = "42"),
    list(name = "y", type = "character", value = "")
  )
  result <- format_variables(vars)
  expect_match(result, "x: <numeric>")
  expect_match(result, "42")
  expect_match(result, "y: <character>")
})

test_that("format_user_query includes all sections with diffs format", {
  input <- list(
    edit_history = "Edit 1 (2025-01-01T00:00:00Z):\nfile.py\n```diff\n@@ -1,3 +1,3 @@\n foo\n-bar\n+baz\n qux\n```",
    excerpt = "```file.py\nprefix\n<|editable_region_start|>\nfoo\nbaz\nqux\n<|editable_region_end|>\nsuffix\n```\n",
    variables = c("x: <numeric>")
  )

  result <- format_user_query(input, edit_history_format = "diffs")
  expect_match(result, "## Edit History")
  expect_match(result, "## Variables")
  expect_match(result, "## Code")
  expect_match(result, "x: <numeric>")
})

test_that("format_user_query omits variables when include_variables = FALSE", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\n<|editable_region_start|>\ncode\n<|editable_region_end|>\n```\n",
    variables = c("x: <numeric>")
  )

  result <- format_user_query(input, include_variables = FALSE)
  expect_no_match(result, "## Variables")
  expect_no_match(result, "x: <numeric>")
})

test_that("format_user_query accepts arbitrary model names", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\n<|editable_region_start|>\ncode\n<|editable_region_end|>\n```\n",
    variables = c("x: <numeric>")
  )
  result <- format_user_query(input, model = "gpt-5-nano")
  expect_match(result, "The following variables are present")
})

test_that("format_user_query omits edit history when NULL", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\n<|editable_region_start|>\ncode\n<|editable_region_end|>\n```\n",
    variables = NULL
  )

  result <- format_user_query(input)
  expect_no_match(result, "Edit History")
  expect_match(result, "## Code")
})

test_that("format_user_query window format replaces markers", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\nprefix\n<|editable_region_start|>\nfoo<|user_cursor_is_here|>\n<|editable_region_end|>\nsuffix\n```\n",
    variables = NULL
  )

  result <- format_user_query(input, output_format = "window")
  expect_no_match(result, "editable_region_start")
  expect_no_match(result, "editable_region_end")
  expect_no_match(result, "user_cursor_is_here")
  expect_match(result, "<cursor>")
  expect_match(result, "rewrite the excerpt")
})

test_that("format_user_query tool_calling format keeps cursor marker", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\nprefix\n<|editable_region_start|>\nfoo<|user_cursor_is_here|>\n<|editable_region_end|>\nsuffix\n```\n",
    variables = NULL
  )

  result <- format_user_query(input, output_format = "tool_calling")
  expect_no_match(result, "editable_region_start")
  expect_no_match(result, "editable_region_end")
  expect_match(result, "user_cursor_is_here", fixed = TRUE)
  expect_match(result, "## File context")
  expect_match(result, "predict the user's next edit")
})

test_that("format_user_query editable_region format preserves markers", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\n<|editable_region_start|>\nfoo<|user_cursor_is_here|>\n<|editable_region_end|>\n```\n",
    variables = NULL
  )

  result <- format_user_query(input, output_format = "editable_region")
  expect_match(result, "editable_region_start", fixed = TRUE)
  expect_match(result, "user_cursor_is_here", fixed = TRUE)
})

test_that("convert_excerpt_to_window extracts filename", {
  excerpt <- "```myfile.py\nsome code\n```\n"
  result <- convert_excerpt_to_window(excerpt)
  expect_match(result, "^```myfile\\.py\n")
})

test_that("format_request_body creates text format for zeta", {
  body <- format_request_body("sys", "user", "zeta")
  expect_named(body, c("prompt", "max_tokens", "min_tokens"))
  expect_equal(body$prompt, "sys\n\nuser")
})

test_that("format_request_body creates chat format for qwen3-8b", {
  body <- format_request_body("sys", "user", "qwen3-8b")
  expect_true("messages" %in% names(body))
  expect_length(body$messages, 2)
  expect_equal(body$messages[[1]]$role, "system")
  expect_equal(body$messages[[2]]$role, "user")
  expect_equal(body$temperature, 0.2)
  expect_false(body$chat_template_kwargs$enable_thinking)
})

test_that("format_request_body includes tools for tool_calling", {
  body <- format_request_body("sys", "user", "qwen3-8b", "tool_calling")
  expect_true("tools" %in% names(body))
  expect_length(body$tools, 1)
  expect_equal(body$tools[[1]]$type, "function")
  expect_equal(body$tools[[1]][["function"]]$name, "edit")
  expect_equal(body$tool_choice, "auto")
})

test_that("format_request_body omits tools for non-tool_calling formats", {
  body <- format_request_body("sys", "user", "qwen3-8b", "window")
  expect_null(body$tools)
  expect_null(body$tool_choice)
})

test_that("format_request_body snapshot: zeta with real sample", {
  input <- samples$input[[1]]
  system_prompt <- "You are a code completion assistant."
  user_content <- format_user_query(input, edit_history_format = "diffs")
  body <- format_request_body(system_prompt, user_content, "zeta")
  expect_snapshot(cat(body$prompt))
})

test_that("format_request_body snapshot: qwen3-8b with real sample", {
  input <- samples$input[[1]]
  system_prompt <- "You are a code completion assistant."
  user_content <- format_user_query(
    input,
    edit_history_format = "before_after",
    output_format = "window"
  )
  body <- format_request_body(system_prompt, user_content, "qwen3-8b")
  expect_snapshot(cat(body$messages[[1]]$content))
  expect_snapshot(cat(body$messages[[2]]$content))
})

read_prompt <- function(name) {
  paste(
    readLines(
      system.file("prompts", paste0(name, ".md"), package = "nesevals"),
      warn = FALSE
    ),
    collapse = "\n"
  )
}

test_that("snapshot: qwen3-8b + diffs + editable_region", {
  input <- samples$input[[1]]
  user_content <- format_user_query(input)
  body <- format_request_body(
    read_prompt("zeta-supercomplete"),
    user_content,
    "qwen3-8b"
  )
  expect_snapshot(cat(body$messages[[1]]$content))
  expect_snapshot(cat(body$messages[[2]]$content))
})

test_that("snapshot: qwen3-8b + narrative + window", {
  input <- samples$input[[1]]
  user_content <- format_user_query(
    input,
    edit_history_format = "narrative",
    output_format = "window"
  )
  body <- format_request_body(
    read_prompt("rewrite-window"),
    user_content,
    "qwen3-8b"
  )
  expect_snapshot(cat(body$messages[[1]]$content))
  expect_snapshot(cat(body$messages[[2]]$content))
})

test_that("snapshot: qwen3-8b + diffs + tool_calling", {
  input <- samples$input[[1]]
  user_content <- format_user_query(
    input,
    edit_history_format = "diffs",
    output_format = "tool_calling"
  )
  body <- format_request_body(
    read_prompt("tool-calling"),
    user_content,
    "qwen3-8b",
    "tool_calling"
  )
  expect_snapshot(cat(body$messages[[1]]$content))
  expect_snapshot(cat(body$messages[[2]]$content))
  expect_snapshot(str(body$tools))
})

test_that("snapshot: qwen3-8b + narrative + rewrite_region", {
  input <- samples$input[[1]]
  user_content <- format_user_query(
    input,
    edit_history_format = "narrative",
    output_format = "rewrite_region"
  )
  body <- format_request_body(
    read_prompt("rewrite-region"),
    user_content,
    "qwen3-8b"
  )
  expect_snapshot(cat(body$messages[[1]]$content))
  expect_snapshot(cat(body$messages[[2]]$content))
})

test_that("snapshot: qwen3-8b + narrative + rewrite_region_5bt", {
  input <- samples$input[[1]]
  user_content <- format_user_query(
    input,
    edit_history_format = "narrative",
    output_format = "rewrite_region_5bt"
  )
  body <- format_request_body(
    read_prompt("rewrite-region-5bt"),
    user_content,
    "qwen3-8b"
  )
  expect_snapshot(cat(body$messages[[1]]$content))
  expect_snapshot(cat(body$messages[[2]]$content))
})

test_that("format_user_query rewrite_region_5bt uses 5-backtick fences", {
  input <- list(
    edit_history = "Edit 1 (2025-01-01T00:00:00Z):\nfile.py\n```diff\n@@ -1,3 +1,3 @@\n foo\n-bar\n+baz\n qux\n```",
    excerpt = "```file.py\nprefix\n<|editable_region_start|>\nfoo<|user_cursor_is_here|>\n<|editable_region_end|>\nsuffix\n```\n",
    variables = c("x: <numeric>")
  )

  result <- format_user_query(
    input,
    edit_history_format = "narrative",
    output_format = "rewrite_region_5bt"
  )
  lines <- strsplit(result, "\n")[[1]]
  fence_lines <- grep("^`+", lines, value = TRUE)
  expect_true(all(grepl("^`{5}", fence_lines)))
  expect_match(result, "## File context")
  expect_match(result, "## Region")
})

test_that("format_user_query rewrite_region format separates context and region", {
  input <- list(
    edit_history = NULL,
    excerpt = "```file.py\nprefix\n<|editable_region_start|>\nfoo<|user_cursor_is_here|>\n<|editable_region_end|>\nsuffix\n```\n",
    variables = NULL
  )

  result <- format_user_query(input, output_format = "rewrite_region")
  expect_no_match(result, "editable_region_start")
  expect_no_match(result, "editable_region_end")
  expect_no_match(result, "user_cursor_is_here")
  expect_match(result, "<cursor>")
  expect_match(result, "## File context")
  expect_match(result, "## Region")
  expect_match(result, "Rewrite the following region")
})

test_that("extract_completion handles rewrite_region format", {
  result <- list(
    choices = list(list(
      message = list(content = "```py\nfoo\nbar\n```")
    ))
  )
  completion <- extract_completion(result, "qwen3-8b", "rewrite_region")
  expect_equal(completion, "foo\nbar")
})

test_that("extract_completion rewrite_region strips cursor", {
  result <- list(
    choices = list(list(
      message = list(content = "foo<cursor>bar")
    ))
  )
  completion <- extract_completion(result, "qwen3-8b", "rewrite_region")
  expect_equal(completion, "foobar")
})

test_that("extract_completion rewrite_region handles plain text", {
  result <- list(
    choices = list(list(
      message = list(content = "just plain code")
    ))
  )
  completion <- extract_completion(result, "qwen3-8b", "rewrite_region")
  expect_equal(completion, "just plain code")
})

test_that("extract_completion handles editable_region format", {
  result <- list(
    choices = list(list(
      message = list(
        content = "<|editable_region_start|>\nfoo\n<|editable_region_end|>"
      )
    ))
  )
  completion <- extract_completion(result, "qwen3-8b", "editable_region")
  expect_equal(completion, "foo")
})

test_that("extract_completion handles window format", {
  result <- list(
    choices = list(list(
      message = list(
        content = "```file.py\nprefix\nedited\nsuffix\n```"
      )
    ))
  )
  excerpt <- paste0(
    "```file.py\nprefix\n",
    "<|editable_region_start|>\noriginal\n<|editable_region_end|>\n",
    "suffix\n```\n"
  )
  completion <- extract_completion(result, "qwen3-8b", "window", excerpt)
  expect_equal(completion, "edited")
})

test_that("extract_completion window format strips cursor marker", {
  result <- list(
    choices = list(list(
      message = list(
        content = "```file.py\nprefix\nedi<cursor>ted\nsuffix\n```"
      )
    ))
  )
  excerpt <- paste0(
    "```file.py\nprefix\n",
    "<|editable_region_start|>\noriginal\n<|editable_region_end|>\n",
    "suffix\n```\n"
  )
  completion <- extract_completion(result, "qwen3-8b", "window", excerpt)
  expect_equal(completion, "edited")
})

test_that("extract_completion returns NA for NULL text", {
  result <- list(choices = list(list(message = list(content = NULL))))
  expect_true(is.na(extract_completion(result, "qwen3-8b", "editable_region")))
})

test_that("extract_completion handles tool_calling with successful edit", {
  result <- list(
    choices = list(list(
      message = list(
        content = NULL,
        tool_calls = list(list(
          `function` = list(
            name = "edit",
            arguments = '{"old": "foo", "new": "bar"}'
          )
        ))
      )
    ))
  )
  excerpt <- "```file.py\n<|editable_region_start|>\nfoo\nbaz\n<|editable_region_end|>\n```\n"
  completion <- extract_completion(result, "qwen3-8b", "tool_calling", excerpt)
  expect_equal(completion, "bar\nbaz", ignore_attr = TRUE)
})

test_that("extract_completion returns NA for tool_calling with no tool call", {
  result <- list(
    choices = list(list(
      message = list(
        content = "No edit needed.",
        tool_calls = NULL
      )
    ))
  )
  excerpt <- "```file.py\n<|editable_region_start|>\nfoo\n<|editable_region_end|>\n```\n"
  expect_true(is.na(extract_completion(
    result,
    "qwen3-8b",
    "tool_calling",
    excerpt
  )))
})

test_that("extract_completion returns NA for tool_calling with malformed args", {
  result <- list(
    choices = list(list(
      message = list(
        tool_calls = list(list(
          `function` = list(
            name = "edit",
            arguments = "not valid json"
          )
        ))
      )
    ))
  )
  excerpt <- "```file.py\n<|editable_region_start|>\nfoo\n<|editable_region_end|>\n```\n"
  expect_true(is.na(extract_completion(
    result,
    "qwen3-8b",
    "tool_calling",
    excerpt
  )))
})

test_that("extract_completion tool_calling strips cursor marker", {
  result <- list(
    choices = list(list(
      message = list(
        tool_calls = list(list(
          `function` = list(
            name = "edit",
            arguments = '{"old": "fo", "new": "foo_bar"}'
          )
        ))
      )
    ))
  )
  excerpt <- "```file.py\n<|editable_region_start|>\nfo<|user_cursor_is_here|>\nbaz\n<|editable_region_end|>\n```\n"
  completion <- extract_completion(result, "qwen3-8b", "tool_calling", excerpt)
  expect_equal(completion, "foo_bar\nbaz", ignore_attr = TRUE)
})

test_that("extract_completion tool_calling returns unchanged region when old == new", {
  result <- list(
    choices = list(list(
      message = list(
        tool_calls = list(list(
          `function` = list(
            name = "edit",
            arguments = '{"old": "foo", "new": "foo"}'
          )
        ))
      )
    ))
  )
  excerpt <- "```file.py\n<|editable_region_start|>\nfoo\nbaz\n<|editable_region_end|>\n```\n"
  completion <- extract_completion(result, "qwen3-8b", "tool_calling", excerpt)
  expect_equal(completion, "foo\nbaz", ignore_attr = TRUE)
})

test_that("strip_code_fences removes fences", {
  expect_equal(strip_code_fences("```py\nfoo\n```"), "foo")
  expect_equal(strip_code_fences("```\nbar\n```"), "bar")
  expect_equal(strip_code_fences("no fences"), "no fences")
  expect_equal(strip_code_fences("```py\n    indented\n```"), "    indented")
})

test_that("strip_code_fences removes 5-backtick fences", {
  expect_equal(strip_code_fences("`````py\nfoo\n`````"), "foo")
  expect_equal(strip_code_fences("`````\nbar\n`````"), "bar")
  expect_equal(
    strip_code_fences("`````py\n    indented\n`````"),
    "    indented"
  )
})

test_that("extract_completion handles rewrite_region_5bt format", {
  result <- list(
    choices = list(list(
      message = list(content = "`````py\nfoo\nbar\n`````")
    ))
  )
  completion <- extract_completion(result, "qwen3-8b", "rewrite_region_5bt")
  expect_equal(completion, "foo\nbar")
})

test_that("process_completion_text handles rewrite_region_5bt", {
  expect_equal(
    process_completion_text("`````py\nfoo\nbar\n`````", "rewrite_region_5bt"),
    "foo\nbar"
  )
})
