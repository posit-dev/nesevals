test_that("completions_load_test validates completions has request column", {
  df <- data.frame(sample_id = "a", response = "b")
  expect_error(
    completions_load_test(df, model = "qwen3-8b"),
    "request"
  )
})

test_that("completions_load_test validates interval", {
  df <- data.frame(sample_id = "a")
  df$request <- list(list())
  expect_error(
    completions_load_test(df, model = "qwen3-8b", interval = -1),
    "interval"
  )
  expect_error(
    completions_load_test(df, model = "qwen3-8b", interval = "a"),
    "interval"
  )
})

test_that("completions_load_test validates n", {
  df <- data.frame(sample_id = "a")
  df$request <- list(list())
  expect_error(
    completions_load_test(df, model = "qwen3-8b", n = 0),
    "n"
  )
})

test_that("completions_load_test requires BASETEN_API_KEY", {
  df <- data.frame(sample_id = "a")
  df$request <- list(list())
  withr::local_envvar(BASETEN_API_KEY = "")
  expect_error(
    completions_load_test(df, model = "qwen3-8b"),
    "BASETEN_API_KEY"
  )
})
