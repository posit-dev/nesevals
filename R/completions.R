#' Generate completions from NES model endpoints
#'
#' @description
#' Send evaluation samples to a model endpoint and collect completions along
#' with response latency. Results are written to JSON files under
#' `inst/results/completions/` and `inst/results/metadata/`.
#'
#' @param samples A data frame of evaluation samples in the same format as
#'   [nesevals::samples].
#' @param model Either a string naming a Baseten model (`"qwen3-8b"` or
#'   `"zeta"`) or an ellmer [ellmer::Chat] object (e.g. from
#'   [ellmer::chat_openai()] or [ellmer::chat_claude()]). When a Chat object
#'   is provided, the model name is derived from `chat$get_model()`. The
#'   `"tool_calling"` output format is not supported with Chat objects.
#' @param prompt One of `"zeta-supercomplete"`, `"qwen-supercomplete"`,
#'   `"rewrite-window"`, `"tool-calling"`, or `"rewrite-region"`. Determines
#'   which system prompt file to use from `inst/prompts/`.
#' @param edit_history_format One of `"diffs"`, `"before_after"`, or
#'   `"narrative"`.
#' @param output_format One of `"editable_region"`, `"window"`,
#'   `"tool_calling"`, or `"rewrite_region"`.
#' @param include_variables Logical. Whether to include variables in the prompt.
#' @param n_replicates Integer. Number of completions to generate per sample.
#' @param context_lines Integer. Number of context lines for before/after and
#'   narrative edit history formats.
#'
#' @returns Invisibly, a data frame with columns `sample_id`, `replicate`,
#'   `response` (character), `latency` (numeric, in seconds),
#'   `tokens_input` (integer), `tokens_output` (integer), and `request`
#'   (list-column containing the request body).
#' @export
completions_generate <- function(
  samples,
  model = c("qwen3-8b", "zeta"),
  prompt = c(
    "zeta-supercomplete",
    "qwen-supercomplete",
    "rewrite-window",
    "tool-calling",
    "rewrite-region",
    "rewrite-region-5bt"
  ),
  edit_history_format = c("diffs", "before_after", "narrative"),
  output_format = c(
    "editable_region",
    "window",
    "tool_calling",
    "rewrite_region",
    "rewrite_region_5bt"
  ),
  include_variables = TRUE,
  n_replicates = 1L,
  context_lines = 1L
) {
  use_ellmer <- inherits(model, "Chat")

  if (use_ellmer) {
    chat <- model
    model_name <- chat$get_model()
  } else {
    model <- match.arg(model)
    model_name <- model
  }

  prompt <- match.arg(prompt)
  edit_history_format <- match.arg(edit_history_format)
  output_format <- match.arg(output_format)
  n_replicates <- as.integer(n_replicates)

  if (use_ellmer && output_format == "tool_calling") {
    cli::cli_abort(
      "The {.val tool_calling} output format is not supported with {.cls Chat} models."
    )
  }

  prompt_file <- system.file(
    "prompts",
    paste0(prompt, ".md"),
    package = "nesevals"
  )
  if (!nzchar(prompt_file)) {
    cli::cli_abort("Prompt file {.val {prompt}} not found.")
  }
  system_prompt <- paste(readLines(prompt_file, warn = FALSE), collapse = "\n")

  if (use_ellmer) {
    chat$set_system_prompt(system_prompt)
  } else {
    api_key <- Sys.getenv("BASETEN_API_KEY")
    if (!nzchar(api_key)) {
      cli::cli_abort(
        "The {.envvar BASETEN_API_KEY} environment variable is not set."
      )
    }
    endpoint_url <- model_url(model)
    warmup_endpoint(endpoint_url, api_key)
  }

  n_samples <- nrow(samples)
  total <- n_samples * n_replicates

  cli::cli_alert_info(
    "Generating completions for {n_samples} sample{?s} with {n_replicates} replicate{?s}"
  )
  cli::cli_progress_bar("Generating completions", total = total)

  results <- vector("list", total)
  idx <- 0L

  for (i in seq_len(n_samples)) {
    sample_id <- samples$id[[i]]
    input <- samples$input[[i]]
    user_content <- format_user_query(
      input,
      model = model_name,
      edit_history_format = edit_history_format,
      output_format = output_format,
      include_variables = include_variables,
      context_lines = context_lines
    )

    for (rep in seq_len(n_replicates)) {
      cli::cli_progress_update()
      idx <- idx + 1L

      if (use_ellmer) {
        tryCatch(
          {
            chat_clone <- chat$clone()
            start_time <- proc.time()[["elapsed"]]
            response_text <- chat_clone$chat(user_content, echo = "none")
            latency <- proc.time()[["elapsed"]] - start_time

            completion <- process_completion_text(
              response_text,
              output_format,
              input$excerpt
            )
            tokens <- chat_clone$get_tokens()
            results[[idx]] <- data.frame(
              sample_id = sample_id,
              replicate = rep,
              response = as.character(completion),
              latency = latency,
              tokens_input = as.integer(tokens$input),
              tokens_output = as.integer(tokens$output),
              tool_old = NA_character_,
              stringsAsFactors = FALSE
            )
            results[[idx]]$request <- list(list(
              system_prompt = system_prompt,
              user_content = user_content
            ))
          },
          error = function(e) {
            cli::cli_alert_warning(
              "Error for sample {sample_id}, replicate {rep}: {conditionMessage(e)}"
            )
            results[[idx]] <<- data.frame(
              sample_id = sample_id,
              replicate = rep,
              response = NA_character_,
              latency = NA_real_,
              tokens_input = NA_integer_,
              tokens_output = NA_integer_,
              tool_old = NA_character_,
              stringsAsFactors = FALSE
            )
            results[[idx]]$request <<- list(list(
              system_prompt = system_prompt,
              user_content = user_content
            ))
          }
        )
      } else {
        body <- format_request_body(
          system_prompt,
          user_content,
          model,
          output_format
        )
        tryCatch(
          {
            start_time <- proc.time()[["elapsed"]]

            response <- httr2::request(endpoint_url) |>
              httr2::req_headers(
                Authorization = paste("Api-Key", api_key),
                `Content-Type` = "application/json"
              ) |>
              httr2::req_body_json(body) |>
              httr2::req_perform()

            latency <- proc.time()[["elapsed"]] - start_time
            result <- httr2::resp_body_json(response)
            completion <- extract_completion(
              result,
              model,
              output_format,
              input$excerpt
            )

            usage <- result$usage
            tool_old <- attr(completion, "tool_old") %||% NA_character_
            results[[idx]] <- data.frame(
              sample_id = sample_id,
              replicate = rep,
              response = as.character(completion),
              latency = latency,
              tokens_input = usage$prompt_tokens %||% NA_integer_,
              tokens_output = usage$completion_tokens %||% NA_integer_,
              tool_old = tool_old,
              stringsAsFactors = FALSE
            )
            results[[idx]]$request <- list(body)
          },
          error = function(e) {
            cli::cli_alert_warning(
              "Error for sample {sample_id}, replicate {rep}: {conditionMessage(e)}"
            )
            results[[idx]] <<- data.frame(
              sample_id = sample_id,
              replicate = rep,
              response = NA_character_,
              latency = NA_real_,
              tokens_input = NA_integer_,
              tokens_output = NA_integer_,
              tool_old = NA_character_,
              stringsAsFactors = FALSE
            )
            results[[idx]]$request <<- list(body)
          }
        )
      }
    }
  }

  cli::cli_progress_done()

  res <- do.call(rbind, results)

  name <- completions_name(
    model_name,
    edit_history_format,
    output_format,
    prompt
  )
  results_dir <- file.path(pkg_root(), "inst", "results")

  completions_dir <- file.path(results_dir, "completions")
  dir.create(completions_dir, recursive = TRUE, showWarnings = FALSE)
  completions_file <- file.path(completions_dir, paste0(name, ".json"))
  jsonlite::write_json(
    res,
    completions_file,
    pretty = TRUE,
    auto_unbox = TRUE
  )

  metadata <- list(
    name = name,
    model = model_name,
    prompt = prompt,
    edit_history_format = edit_history_format,
    output_format = output_format,
    include_variables = include_variables,
    n_replicates = n_replicates,
    context_lines = context_lines,
    n_samples = nrow(samples),
    generated_at = as.character(Sys.time())
  )
  metadata_dir <- file.path(results_dir, "metadata")
  dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)
  metadata_file <- file.path(metadata_dir, paste0(name, ".json"))
  jsonlite::write_json(
    metadata,
    metadata_file,
    pretty = TRUE,
    auto_unbox = TRUE
  )

  cli::cli_alert_success("Completions saved to {.path {completions_file}}")
  cli::cli_alert_success("Metadata saved to {.path {metadata_file}}")

  attr(res, "name") <- name
  invisible(res)
}

extract_completion <- function(result, model, output_format, excerpt = NULL) {
  if (output_format == "tool_calling") {
    return(extract_tool_call_completion(result, excerpt))
  }

  text <- if (model == "zeta") {
    result$choices[[1]]$text
  } else {
    result$choices[[1]]$message$content
  }

  process_completion_text(text, output_format, excerpt)
}

process_completion_text <- function(text, output_format, excerpt = NULL) {
  if (is.null(text)) {
    return(NA_character_)
  }

  if (output_format == "editable_region") {
    if (!has_editable_region(text)) {
      return(NA_character_)
    }
    text <- extract_region_text(text)
    text <- gsub("<\\|user_cursor_is_here\\|>", "", text)
  } else if (output_format == "window") {
    text <- extract_region_from_window(text, excerpt)
    text <- gsub("<cursor>", "", text, fixed = TRUE)
  } else if (output_format %in% c("rewrite_region", "rewrite_region_5bt")) {
    text <- strip_code_fences(text)
    text <- gsub("<cursor>", "", text, fixed = TRUE)
  }

  text
}

extract_tool_call_completion <- function(result, excerpt) {
  tool_calls <- result$choices[[1]]$message$tool_calls
  if (is.null(tool_calls) || length(tool_calls) == 0L) {
    return(NA_character_)
  }

  args_json <- tool_calls[[1]]$`function`$arguments
  if (is.null(args_json)) {
    return(NA_character_)
  }

  args <- tryCatch(
    jsonlite::fromJSON(args_json),
    error = function(e) NULL
  )
  if (is.null(args) || is.null(args$old) || is.null(args$new)) {
    return(NA_character_)
  }

  region_text <- extract_region_text(excerpt)
  region_text <- gsub("<\\|user_cursor_is_here\\|>", "", region_text)

  args$old <- gsub("<|user_cursor_is_here|>", "", args$old, fixed = TRUE)
  args$new <- gsub("<|user_cursor_is_here|>", "", args$new, fixed = TRUE)

  if (args$old == args$new) {
    res <- region_text
    attr(res, "tool_old") <- args$old
    return(res)
  }

  n_matches <- length(gregexpr(args$old, region_text, fixed = TRUE)[[1]])
  if (n_matches > 1L) {
    res <- region_text
    attr(res, "tool_old") <- args$old
    return(res)
  }

  res <- sub(args$old, args$new, region_text, fixed = TRUE)
  attr(res, "tool_old") <- args$old
  res
}

has_editable_region <- function(text) {
  start_marker <- "<|editable_region_start|>"
  end_marker <- "<|editable_region_end|>"
  n_start <- length(gregexpr(start_marker, text, fixed = TRUE)[[1]])
  n_end <- length(gregexpr(end_marker, text, fixed = TRUE)[[1]])
  start_found <- regexpr(start_marker, text, fixed = TRUE) != -1L
  start_found && n_start == 1L && n_end == 1L
}

strip_code_fences <- function(text) {
  text <- trimws(text)
  open_match <- regmatches(text, regexpr("^`{3,}", text))
  if (length(open_match) > 0L && nzchar(open_match)) {
    fence_len <- nchar(open_match)
    text <- sub("^`{3,}[a-zA-Z0-9_./-]*\n?", "", text)
    closing_pattern <- paste0("\n`{", fence_len, ",}[\\s\\S]*$")
    text <- sub(closing_pattern, "", text, perl = TRUE)
  }
  sub("^[\r\n]+", "", sub("[\r\n]+$", "", text))
}

extract_region_from_window <- function(text, excerpt) {
  text <- strip_code_fences(text)

  if (is.null(excerpt)) {
    return(text)
  }

  parts <- parse_excerpt(excerpt)

  prefix <- sub("^```[a-zA-Z0-9_./-]*\n?", "", parts$prefix)
  prefix <- sub("\n$", "", prefix)

  suffix <- sub("\n?```\\s*$", "", parts$suffix)
  suffix <- sub("^\n", "", suffix)

  if (nzchar(prefix) && startsWith(text, prefix)) {
    text <- substr(text, nchar(prefix) + 1, nchar(text))
    text <- sub("^\n", "", text)
  }

  if (nzchar(suffix) && endsWith(text, suffix)) {
    text <- substr(text, 1, nchar(text) - nchar(suffix))
    text <- sub("\n$", "", text)
  }

  text
}

#' Read saved completions
#'
#' @description
#' Load a previously saved completions result set from
#' `inst/results/completions/`.
#'
#' @param name The name of the result set, e.g.
#'   `"qwen3-8b_diffs_editable-region_zeta-supercomplete"`. This
#'   corresponds to the filename (without `.json`) under
#'   `inst/results/completions/`.
#'
#' @returns A data frame with columns `sample_id`, `replicate`, `response`,
#'   `latency`, `tokens_input`, and `tokens_output`.
#' @export
completions_read <- function(name) {
  path <- file.path(
    pkg_root(),
    "inst",
    "results",
    "completions",
    paste0(name, ".json")
  )
  if (!file.exists(path)) {
    cli::cli_abort("Completions file not found: {.path {path}}")
  }
  raw <- jsonlite::fromJSON(path, simplifyDataFrame = FALSE)
  res <- data.frame(
    sample_id = vapply(raw, function(x) x$sample_id, character(1)),
    replicate = vapply(raw, function(x) x$replicate, integer(1)),
    response = vapply(
      raw,
      function(x) x$response %||% NA_character_,
      character(1)
    ),
    latency = vapply(raw, function(x) x$latency %||% NA_real_, double(1)),
    tokens_input = vapply(
      raw,
      function(x) x$tokens_input %||% NA_integer_,
      integer(1)
    ),
    tokens_output = vapply(
      raw,
      function(x) x$tokens_output %||% NA_integer_,
      integer(1)
    ),
    tool_old = vapply(
      raw,
      function(x) x$tool_old %||% NA_character_,
      character(1)
    ),
    stringsAsFactors = FALSE
  )
  res$request <- lapply(raw, function(x) x$request)
  attr(res, "name") <- name
  res
}

completions_name <- function(
  model,
  edit_history_format,
  output_format,
  prompt
) {
  paste(
    gsub("/", "--", model),
    gsub("_", "-", edit_history_format),
    gsub("_", "-", output_format),
    prompt,
    sep = "_"
  )
}

warmup_endpoint <- function(endpoint_url, api_key) {
  cli::cli_alert_info("Warming up endpoint...")
  body <- list(
    messages = list(
      list(role = "user", content = "hi")
    ),
    max_tokens = 1L,
    chat_template_kwargs = list(enable_thinking = FALSE)
  )
  tryCatch(
    httr2::request(endpoint_url) |>
      httr2::req_headers(
        Authorization = paste("Api-Key", api_key),
        `Content-Type` = "application/json"
      ) |>
      httr2::req_body_json(body) |>
      httr2::req_perform(),
    error = function(e) {
      cli::cli_alert_warning("Warmup request failed: {conditionMessage(e)}")
    }
  )
  Sys.sleep(1)
}

pkg_root <- function() {
  dir <- getwd()
  while (!file.exists(file.path(dir, "DESCRIPTION"))) {
    parent <- dirname(dir)
    if (parent == dir) {
      cli::cli_abort("Could not find package root (no DESCRIPTION file).")
    }
    dir <- parent
  }
  dir
}
