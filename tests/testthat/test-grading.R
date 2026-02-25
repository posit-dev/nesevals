test_that("grade_processable rejects NA and empty strings", {
  expect_false(grade_processable(NA_character_))
  expect_false(grade_processable(""))
  expect_false(grade_processable("   "))
  expect_true(grade_processable("some code"))
})

test_that("grade_exact_match ignores leading/trailing whitespace", {
  expect_true(grade_exact_match("x <- 1", "x <- 1"))
  expect_true(grade_exact_match("  x <- 1  ", "x <- 1"))
  expect_true(grade_exact_match("x <- 1", "  x <- 1\n"))
  expect_false(grade_exact_match("x <- 1", "x <- 2"))
})

test_that("build_sample_lookups extracts targets, excerpts, and variables", {
  samples <- data.frame(
    id = c("s1", "s2"),
    output = c(
      "<|editable_region_start|>\nx <- 1\n<|editable_region_end|>",
      "<|editable_region_start|>\ny <- 2\n<|editable_region_end|>"
    ),
    stringsAsFactors = FALSE
  )
  excerpt1 <- "```file.R\nprefix\n<|editable_region_start|>\nx <- 1\n<|editable_region_end|>\nsuffix\n```"
  excerpt2 <- "```file.R\n<|editable_region_start|>\ny <- 2\n<|editable_region_end|>\n```"
  samples$input <- list(
    list(
      excerpt = excerpt1,
      variables = list(list(name = "x", type = "numeric", value = "1")),
      edit_history = "some diff for s1"
    ),
    list(
      excerpt = excerpt2,
      variables = list(list(name = "y", type = "numeric", value = "2")),
      edit_history = "some diff for s2"
    )
  )
  lookups <- build_sample_lookups(samples)
  expect_equal(lookups$targets[["s1"]], "x <- 1")
  expect_equal(lookups$targets[["s2"]], "y <- 2")
  expect_equal(lookups$excerpts[["s1"]], excerpt1)
  expect_equal(lookups$excerpts[["s2"]], excerpt2)
  expect_equal(lookups$variables[["s1"]][[1]]$name, "x")
  expect_equal(lookups$variables[["s2"]][[1]]$name, "y")
  expect_equal(lookups$edit_histories[["s1"]], "some diff for s1")
  expect_equal(lookups$edit_histories[["s2"]], "some diff for s2")
})

test_that("build_grading_prompt includes excerpt, target, response, variables, and edit history", {
  excerpt <- "```file.R\nprefix\n<|editable_region_start|>\nx <- 1\n<|editable_region_end|>\nsuffix\n```"
  edit_history <- "```file.R\n@@ -1,1 +1,1 @@\n-x <- 0\n+x <- 1\n```"
  prompt <- build_grading_prompt(
    "x <- 1",
    "x <- 2",
    excerpt,
    "x: <numeric>",
    edit_history
  )
  expect_match(prompt, "x <- 1", fixed = TRUE)
  expect_match(prompt, "x <- 2", fixed = TRUE)
  expect_match(prompt, "prefix", fixed = TRUE)
  expect_match(prompt, "suffix", fixed = TRUE)
  expect_match(prompt, "{excerpt}", fixed = TRUE)
  expect_match(prompt, "{editable_input}", fixed = TRUE)
  expect_match(prompt, "x: <numeric>", fixed = TRUE)
  expect_match(prompt, "{edit_history}", fixed = TRUE)
  expect_match(prompt, "x <- 0", fixed = TRUE)
  expect_match(prompt, "EQUIVALENT", fixed = TRUE)
  expect_match(prompt, "WRONG", fixed = TRUE)
})

test_that("build_grading_prompt omits variables section when empty", {
  excerpt <- "```file.R\n<|editable_region_start|>\nx <- 1\n<|editable_region_end|>\n```"
  prompt <- build_grading_prompt("x <- 1", "x <- 2", excerpt, "")
  expect_no_match(prompt, "{variables}", fixed = TRUE)
})

test_that("build_grading_prompt omits edit history section when empty", {
  excerpt <- "```file.R\n<|editable_region_start|>\nx <- 1\n<|editable_region_end|>\n```"
  prompt <- build_grading_prompt("x <- 1", "x <- 2", excerpt, "", "")
  expect_no_match(prompt, "{edit_history}", fixed = TRUE)
})

test_that("build_grading_prompt describes tag options", {
  excerpt <- "```file.R\n<|editable_region_start|>\nx <- 1\n<|editable_region_end|>\n```"
  prompt <- build_grading_prompt("x <- 1", "x <- 2", excerpt, "")
  for (tag in grading_tags()) {
    expect_match(prompt, tag, fixed = TRUE)
  }
})

test_that("grading_tags returns expected tags", {
  tags <- grading_tags()
  expect_true("correct" %in% tags)
  expect_true("truncated" %in% tags)
  expect_true("hallucinated_name" %in% tags)
})
