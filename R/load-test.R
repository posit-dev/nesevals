#' Replay stored completions at a fixed request rate
#'
#' @description
#' Send previously collected completion requests at a controlled interval.
#' This is useful for load testing: run against the Qwen3-8B endpoint, then
#' again against Zeta at the same rate, and compare GPU utilisation on
#' Baseten.
#'
#' Requests are dispatched asynchronously using `curl`'s multi interface, so
#' new requests go out on schedule even when previous responses are still
#' in flight.
#'
#' @param completions A data frame returned by [completions_read()] that
#'   contains a `request` list-column with the original request bodies.
#' @param model One of `"qwen3-8b"` or `"zeta"`. Determines which Baseten
#'   endpoint to target.
#' @param interval Target number of seconds between consecutive requests.
#'   For example, `0.2` sends 5 requests per second.
#' @param n Number of requests to send. Defaults to `nrow(completions)`.
#'   If `n` exceeds the number of stored requests, they are recycled.
#'
#' @returns Invisibly, a data frame with columns `request_index`,
#'   `scheduled_time`, `actual_send_time`, `latency`, `tokens_input`, and
#'   `tokens_output`.
#' @export
completions_load_test <- function(
  completions,
  model = c("qwen3-8b", "zeta"),
  interval = 0.2,
  n = NULL
) {
  model <- match.arg(model)

  if (!"request" %in% names(completions)) {
    cli::cli_abort(
      "{.arg completions} must have a {.field request} column
       (from {.fn completions_read})."
    )
  }

  if (!is.numeric(interval) || length(interval) != 1L || interval <= 0) {
    cli::cli_abort("{.arg interval} must be a single positive number.")
  }

  n <- as.integer(n %||% nrow(completions))
  if (n < 1L) {
    cli::cli_abort("{.arg n} must be at least 1.")
  }

  api_key <- Sys.getenv("BASETEN_API_KEY")
  if (!nzchar(api_key)) {
    cli::cli_abort(
      "The {.envvar BASETEN_API_KEY} environment variable is not set."
    )
  }

  endpoint_url <- model_url(model)

  warmup_endpoint(endpoint_url, api_key)

  cli::cli_alert_info(
    "Sending {n} request{?s} at {1 / interval} req/s to {.val {model}}"
  )

  results <- vector("list", n)
  send_times <- numeric(n)
  pool <- curl::new_pool()
  next_i <- 1L
  done_count <- 0L

  cli::cli_progress_bar("Load testing", total = n)
  origin <- proc.time()[["elapsed"]]

  make_done_cb <- function(idx, sent_at) {
    function(resp) {
      latency <- proc.time()[["elapsed"]] - sent_at
      parsed <- tryCatch(
        jsonlite::fromJSON(rawToChar(resp$content)),
        error = function(e) list()
      )
      usage <- parsed$usage
      results[[idx]] <<- data.frame(
        request_index = idx,
        scheduled_time = (idx - 1L) * interval,
        actual_send_time = sent_at - origin,
        latency = latency,
        tokens_input = usage$prompt_tokens %||% NA_integer_,
        tokens_output = usage$completion_tokens %||% NA_integer_,
        stringsAsFactors = FALSE
      )
      done_count <<- done_count + 1L
    }
  }

  make_fail_cb <- function(idx, sent_at) {
    function(msg) {
      cli::cli_alert_warning("Request {idx} failed: {msg}")
      results[[idx]] <<- data.frame(
        request_index = idx,
        scheduled_time = (idx - 1L) * interval,
        actual_send_time = sent_at - origin,
        latency = NA_real_,
        tokens_input = NA_integer_,
        tokens_output = NA_integer_,
        stringsAsFactors = FALSE
      )
      done_count <<- done_count + 1L
    }
  }

  prev_done <- 0L
  while (done_count < n) {
    while (next_i <= n) {
      scheduled <- (next_i - 1L) * interval
      now <- proc.time()[["elapsed"]] - origin
      if (now < scheduled) {
        break
      }

      body <- completions$request[[(next_i - 1L) %% nrow(completions) + 1L]]
      json_body <- jsonlite::toJSON(body, auto_unbox = TRUE)

      h <- curl::new_handle()
      curl::handle_setheaders(
        h,
        Authorization = paste("Api-Key", api_key),
        `Content-Type` = "application/json"
      )
      curl::handle_setopt(h, postfields = json_body)

      sent_at <- proc.time()[["elapsed"]]
      curl::multi_add(
        curl::new_handle(url = endpoint_url) |>
          curl::handle_setheaders(
            Authorization = paste("Api-Key", api_key),
            `Content-Type` = "application/json"
          ) |>
          curl::handle_setopt(postfields = json_body),
        done = make_done_cb(next_i, sent_at),
        fail = make_fail_cb(next_i, sent_at),
        pool = pool
      )

      next_i <- next_i + 1L
    }

    wait_time <- if (next_i <= n) {
      scheduled <- (next_i - 1L) * interval
      now <- proc.time()[["elapsed"]] - origin
      max(scheduled - now, 0.001)
    } else {
      1
    }
    curl::multi_run(timeout = wait_time, pool = pool)

    if (done_count > prev_done) {
      cli::cli_progress_update(set = done_count)
      prev_done <- done_count
    }
  }

  cli::cli_progress_done()

  res <- do.call(rbind, results)
  load_test_summary(res, model, interval, n)
  invisible(res)
}

load_test_summary <- function(res, model, interval, n) {
  total_duration <- max(res$actual_send_time, na.rm = TRUE)
  valid <- res$latency[!is.na(res$latency)]

  cli::cli_rule("{.val {model}} load test summary")
  cli::cli_bullets(c(
    "*" = "Requests: {length(valid)}/{n} succeeded",
    "*" = "Duration: {round(total_duration, 1)}s
           (target: {round((n - 1) * interval, 1)}s)",
    "*" = "Actual rate: {round(length(valid) / total_duration, 1)} req/s
           (target: {round(1 / interval, 1)} req/s)",
    "*" = "Latency \u2014 mean: {round(mean(valid) * 1000)}ms,
           median: {round(stats::median(valid) * 1000)}ms,
           p95: {round(stats::quantile(valid, 0.95) * 1000)}ms"
  ))
}
