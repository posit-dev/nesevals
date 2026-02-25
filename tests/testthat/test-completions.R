test_that("resolve_results_dir uses argument first", {
  expect_equal(resolve_results_dir("/tmp/custom"), "/tmp/custom")
})

test_that("resolve_results_dir uses option when set", {
  withr::local_options(nesevals.results_dir = "/tmp/custom-results")
  expect_equal(resolve_results_dir(), "/tmp/custom-results")
})

test_that("resolve_results_dir falls back to package root", {
  pkg_dir <- normalizePath(withr::local_tempdir())
  file.create(file.path(pkg_dir, "DESCRIPTION"))
  withr::local_dir(pkg_dir)
  withr::local_options(nesevals.results_dir = NULL)
  expect_equal(resolve_results_dir(), file.path(pkg_dir, "inst", "results"))
})

test_that("resolve_results_dir falls back to working directory", {
  tmp_dir <- normalizePath(withr::local_tempdir())
  withr::local_dir(tmp_dir)
  withr::local_options(nesevals.results_dir = NULL)
  expect_equal(resolve_results_dir(), file.path(tmp_dir, "nesevals-results"))
})

test_that("completions_name derives name from params", {
  expect_equal(
    completions_name(
      "qwen3-8b",
      "diffs",
      "editable_region",
      "zeta-supercomplete"
    ),
    "qwen3-8b_diffs_editable-region_zeta-supercomplete"
  )
  expect_equal(
    completions_name("zeta", "before_after", "window", "rewrite-window"),
    "zeta_before-after_window_rewrite-window"
  )
})

test_that("completions_name works with arbitrary model names", {
  expect_equal(
    completions_name(
      "gpt-5-nano",
      "narrative",
      "rewrite_region",
      "rewrite-region"
    ),
    "gpt-5-nano_narrative_rewrite-region_rewrite-region"
  )
})

test_that("completions_generate errors for tool_calling with Chat model", {
  mock_chat <- structure(
    list(
      get_model = function() "test-model"
    ),
    class = "Chat"
  )
  expect_error(
    completions_generate(
      samples[1, ],
      model = mock_chat,
      prompt = "rewrite-region",
      output_format = "tool_calling"
    ),
    "tool_calling.*not supported"
  )
})

test_that("process_completion_text handles rewrite_region", {
  expect_equal(
    process_completion_text("```py\nfoo\nbar\n```", "rewrite_region"),
    "foo\nbar"
  )
})

test_that("process_completion_text handles editable_region", {
  text <- "<|editable_region_start|>\nfoo\n<|editable_region_end|>"
  expect_equal(process_completion_text(text, "editable_region"), "foo")
})

test_that("process_completion_text returns NA for NULL", {
  expect_true(is.na(process_completion_text(NULL, "rewrite_region")))
})

test_that("process_completion_text strips cursor from rewrite_region", {
  expect_equal(
    process_completion_text("```py\nfoo<cursor>bar\n```", "rewrite_region"),
    "foobar"
  )
})

test_that("process_completion_text strips cursor from window", {
  text <- "```file.py\nprefix\nedi<cursor>ted\nsuffix\n```"
  excerpt <- paste0(
    "```file.py\nprefix\n",
    "<|editable_region_start|>\noriginal\n<|editable_region_end|>\n",
    "suffix\n```\n"
  )
  expect_equal(
    process_completion_text(text, "window", excerpt),
    "edited"
  )
})

test_that("completions_read round-trips with write_json", {
  pkg_dir <- withr::local_tempdir()
  file.create(file.path(pkg_dir, "DESCRIPTION"))
  completions_dir <- file.path(pkg_dir, "inst", "results", "completions")
  dir.create(completions_dir, recursive = TRUE)

  data <- data.frame(
    sample_id = c("a", "a"),
    replicate = c(1L, 2L),
    response = c("foo", "bar"),
    latency = c(0.1, 0.2),
    stringsAsFactors = FALSE
  )
  jsonlite::write_json(
    data,
    file.path(completions_dir, "test-run.json"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  withr::local_dir(pkg_dir)
  res <- completions_read("test-run")
  expect_equal(nrow(res), 2)
  expect_equal(res$sample_id, c("a", "a"))
  expect_equal(res$response, c("foo", "bar"))
  expect_equal(res$latency, c(0.1, 0.2))
})

test_that("completions_read preserves request column", {
  pkg_dir <- withr::local_tempdir()
  file.create(file.path(pkg_dir, "DESCRIPTION"))
  completions_dir <- file.path(pkg_dir, "inst", "results", "completions")
  dir.create(completions_dir, recursive = TRUE)

  data <- data.frame(
    sample_id = "a",
    replicate = 1L,
    response = "foo",
    latency = 0.1,
    tokens_input = 10L,
    tokens_output = 5L,
    tool_old = NA_character_,
    stringsAsFactors = FALSE
  )
  data$request <- list(list(
    messages = list(list(role = "user", content = "hi"))
  ))
  jsonlite::write_json(
    data,
    file.path(completions_dir, "test-run.json"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  withr::local_dir(pkg_dir)
  res <- completions_read("test-run")
  expect_true("request" %in% names(res))
  expect_equal(res$request[[1]]$messages[[1]]$content, "hi")
})

test_that("completions_read errors for missing file", {
  pkg_dir <- withr::local_tempdir()
  file.create(file.path(pkg_dir, "DESCRIPTION"))
  withr::local_dir(pkg_dir)
  expect_error(completions_read("nonexistent"), "not found")
})
