test_that("nes_results dataset has expected structure", {
  expect_s3_class(nes_results, "data.frame")

  expected_cols <- c(
    "model",
    "prompt",
    "edit_history",
    "output_format",
    "n_completions",
    "n_processable",
    "n_exact",
    "mean_score",
    "median_latency_ms",
    "mean_input_tokens",
    "mean_output_tokens"
  )
  expect_named(nes_results, expected_cols)

  expect_type(nes_results$model, "character")
  expect_type(nes_results$prompt, "character")
  expect_type(nes_results$edit_history, "character")
  expect_type(nes_results$output_format, "character")
  expect_type(nes_results$n_completions, "integer")
  expect_type(nes_results$n_processable, "integer")
  expect_type(nes_results$n_exact, "integer")
  expect_type(nes_results$mean_score, "double")
  expect_type(nes_results$median_latency_ms, "double")
  expect_type(nes_results$mean_input_tokens, "double")
  expect_type(nes_results$mean_output_tokens, "double")
})

test_that("nes_results dataset has one row per config in inst/results/", {
  n_configs <- length(list.files(
    file.path(resolve_results_dir(), "completions")
  ))
  expect_equal(nrow(nes_results), n_configs)
})

test_that("nes_results scores are in valid range", {
  expect_true(all(nes_results$mean_score >= 0 & nes_results$mean_score <= 5))
  expect_true(all(nes_results$n_processable <= nes_results$n_completions))
  expect_true(all(nes_results$n_exact <= nes_results$n_processable))
})

test_that("nes_results are sorted by mean_score descending", {
  expect_equal(
    nes_results$mean_score,
    sort(nes_results$mean_score, decreasing = TRUE)
  )
})
