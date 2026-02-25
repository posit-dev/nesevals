#' Grade NES completions
#'
#' @description
#' Score completions against target outputs using a multi-tiered system:
#'
#' 1. **Processability**: Is the response non-`NA` and non-empty?
#' 2. **Exact match**: Does the response exactly match the target? If so,
#'    score 5 without an LLM call.
#' 3. **LLM quality grading**: For non-exact-match processable completions,
#'    an LLM judge scores the completion on a 0--5 scale.
#'
#' @param completions A data frame as returned by [completions_generate()] or
#'   [completions_read()], with at least columns `sample_id`, `replicate`, and
#'   `response`.
#' @param samples A data frame of evaluation samples in the same format as
#'   [nesevals::nes_samples]. Must contain all `sample_id` values present in
#'   `completions`.
#' @param name Character. Name for the saved scores file. Defaults to the
#'   `"name"` attribute of `completions` (set automatically by
#'   [completions_generate()] and [completions_read()]). If `NULL`, scores
#'   are not saved to disk.
#' @param max_active Integer. Maximum number of simultaneous LLM grading
#'   requests.
#' @inheritParams completions_generate
#'
#' @returns A data frame with columns `sample_id`, `replicate`, `processable`,
#'   `exact_match`, `score` (integer, 0--5), `reasoning` (character), and
#'   `tags` (list-column of character vectors).
#' @export
completions_grade <- function(
  completions,
  samples,
  name = attr(completions, "name"),
  max_active = 5L,
  results_dir = NULL
) {
  lookups <- build_sample_lookups(samples)
  targets <- lookups$targets
  variables <- lookups$variables
  excerpts <- lookups$excerpts
  edit_histories <- lookups$edit_histories

  n <- nrow(completions)
  processable <- logical(n)
  exact_match <- logical(n)
  score <- integer(n)
  reasoning <- character(n)
  tags <- vector("list", n)

  cli::cli_progress_bar("Grading completions", total = n)

  for (i in seq_len(n)) {
    cli::cli_progress_update()
    response <- completions$response[[i]]
    sample_id <- completions$sample_id[[i]]
    target <- targets[[sample_id]]

    if (!grade_processable(response)) {
      processable[i] <- FALSE
      exact_match[i] <- FALSE
      score[i] <- 0L
      reasoning[i] <- "Not processable"
      tags[[i]] <- "not_processable"
      next
    }

    processable[i] <- TRUE

    if (grade_ambiguous_old(completions, i, excerpts[[sample_id]])) {
      exact_match[i] <- FALSE
      score[i] <- 3L
      reasoning[i] <- "Tool call old string matches multiple locations"
      tags[[i]] <- c("no_edit", "ambiguous_old")
      next
    }

    if (grade_exact_match(response, target)) {
      exact_match[i] <- TRUE
      score[i] <- 5L
      reasoning[i] <- "Exact match"
      tags[[i]] <- "exact_match"
      next
    }

    exact_match[i] <- FALSE
    score[i] <- NA_integer_
    reasoning[i] <- NA_character_
    tags[[i]] <- character()
  }
  cli::cli_progress_done()

  needs_llm <- which(processable & !exact_match)
  if (length(needs_llm) > 0L) {
    cli::cli_alert_info(
      "LLM grading {length(needs_llm)} completion{?s} (skipping {sum(exact_match)} exact match{?es})"
    )
    llm_ids <- completions$sample_id[needs_llm]
    llm_results <- grade_with_llm(
      completions$response[needs_llm],
      vapply(llm_ids, function(id) targets[[id]], character(1)),
      vapply(llm_ids, function(id) excerpts[[id]], character(1)),
      lapply(llm_ids, function(id) variables[[id]]),
      vapply(llm_ids, function(id) edit_histories[[id]], character(1)),
      max_active = max_active
    )
    score[needs_llm] <- llm_results$score
    reasoning[needs_llm] <- llm_results$reasoning
    tags[needs_llm] <- llm_results$tags
  }

  res <- data.frame(
    sample_id = completions$sample_id,
    replicate = completions$replicate,
    processable = processable,
    exact_match = exact_match,
    score = score,
    reasoning = reasoning,
    stringsAsFactors = FALSE
  )
  res$tags <- tags

  if (!is.null(name)) {
    scores_dir <- file.path(resolve_results_dir(results_dir), "scores")
    dir.create(scores_dir, recursive = TRUE, showWarnings = FALSE)
    scores_file <- file.path(scores_dir, paste0(name, ".json"))
    jsonlite::write_json(res, scores_file, pretty = TRUE, auto_unbox = TRUE)
    cli::cli_alert_success("Scores saved to {.path {scores_file}}")
  }

  n_processable <- sum(processable)
  n_exact <- sum(exact_match)
  mean_score <- mean(score, na.rm = TRUE)
  cli::cli_h2("Grading Summary")
  cli::cli_alert_info(
    "Processable: {n_processable}/{n} ({round(100 * n_processable / n, 1)}%)"
  )
  cli::cli_alert_info(
    "Exact matches: {n_exact}/{n_processable}"
  )
  cli::cli_alert_info(
    "Mean score: {round(mean_score, 2)}/5"
  )

  invisible(res)
}

grade_processable <- function(response) {
  !is.na(response) && nzchar(trimws(response))
}

grade_ambiguous_old <- function(completions, i, excerpt) {
  if (!"tool_old" %in% names(completions)) {
    return(FALSE)
  }
  tool_old <- completions$tool_old[[i]]
  if (is.na(tool_old) || !nzchar(tool_old)) {
    return(FALSE)
  }
  region_text <- extract_region_text(excerpt)
  region_text <- gsub("<\\|user_cursor_is_here\\|>", "", region_text)
  matches <- gregexpr(tool_old, region_text, fixed = TRUE)[[1]]
  length(matches) > 1L && matches[1] != -1L
}

grade_exact_match <- function(response, target) {
  trimws(response) == trimws(target)
}

grade_with_llm <- function(
  responses,
  targets,
  excerpts,
  variables,
  edit_histories,
  max_active = 5L
) {
  variables_strs <- vapply(variables, format_variables, character(1))
  prompts <- Map(
    build_grading_prompt,
    response = responses,
    target = targets,
    excerpt = excerpts,
    variables = variables_strs,
    edit_history = edit_histories
  )

  chat <- ellmer::chat_anthropic(
    model = "claude-sonnet-4-5-20250929",
    params = ellmer::params(max_tokens = 1024L)
  )

  type_grade <- ellmer::type_object(
    reasoning = ellmer::type_string(
      "**Brief** reasoning about the quality of the completion, 1-2 sentences."
    ),
    score = ellmer::type_enum(
      as.character(0:5),
      "Score from 0 to 5."
    ),
    tags = ellmer::type_array(
      ellmer::type_enum(
        grading_tags(),
        "A failure mode tag."
      ),
      paste0(
        "Tag the failure modes present in this completion. ",
        "Use 'correct' if the output is equivalent to the target. ",
        "Multiple tags can apply (e.g. both 'truncated' and 'syntax_error')."
      )
    )
  )

  raw <- ellmer::parallel_chat_structured(
    chat,
    prompts,
    type = type_grade,
    convert = FALSE,
    max_active = max_active,
    on_error = "continue"
  )

  score <- integer(length(raw))
  reasoning <- character(length(raw))
  tags <- vector("list", length(raw))

  for (i in seq_along(raw)) {
    r <- raw[[i]]
    if (is.null(r) || inherits(r, "error") || !is.list(r)) {
      score[i] <- 0L
      reasoning[i] <- "Grading failed"
      tags[[i]] <- character()
    } else {
      score[i] <- as.integer(r$score)
      reasoning[i] <- r$reasoning
      tags[[i]] <- as.character(r$tags)
    }
  }

  n_failed <- sum(score == 0L & reasoning == "Grading failed")
  if (n_failed > 0L) {
    cli::cli_alert_warning("{n_failed} grading request{?s} failed")
  }

  list(score = score, reasoning = reasoning, tags = tags)
}

grading_tags <- function() {
  c(
    "correct",
    "truncated",
    "extra_lines",
    "no_edit",
    "wrong_name",
    "hallucinated_name",
    "valid_alternative",
    "syntax_error"
  )
}

build_grading_prompt <- function(
  response,
  target,
  excerpt,
  variables,
  edit_history = ""
) {
  parts <- parse_excerpt(excerpt)
  editable_input <- gsub("<\\|user_cursor_is_here\\|>", "", parts$editable)

  variables_section <- if (nzchar(variables)) {
    paste0(
      "The following variables were in scope in the user's session. ",
      "Use these to judge whether names in the model's output are real or hallucinated.\n\n",
      "{variables}\n",
      variables,
      "\n",
      "{/variables}\n\n"
    )
  } else {
    ""
  }

  edit_history_section <- if (nzchar(edit_history)) {
    paste0(
      "The user's recent edit history (diffs from earlier to later):\n\n",
      "{edit_history}\n",
      edit_history,
      "\n",
      "{/edit_history}\n\n"
    )
  } else {
    ""
  }

  paste0(
    "You are grading a next-edit suggestion (NES) model's output. ",
    "The model was given a code excerpt with a cursor position and recent edit history, ",
    "then asked to predict the user's next edit. The model's task was to rewrite the ",
    "editable region of the excerpt.\n\n",
    edit_history_section,
    "Full excerpt provided to the model (the editable region is between the markers):\n\n",
    "{excerpt}\n",
    excerpt,
    "\n",
    "{/excerpt}\n\n",
    "Editable region input (what the model was asked to rewrite):\n\n",
    "{editable_input}\n",
    editable_input,
    "\n",
    "{/editable_input}\n\n",
    variables_section,
    "Target output (the expected rewrite of the editable region):\n\n",
    "{target}\n",
    target,
    "\n",
    "{/target}\n\n",
    "Model's output:\n\n",
    "{model_output}\n",
    response,
    "\n",
    "{/model_output}\n\n",
    "Grade the model's output from 0-5:\n",
    "- EQUIVALENT (5): Same edit as target, or functionally equivalent\n",
    "- PARTIAL (3): Edited the right location with valid syntax, but wrong value or content ",
    "(e.g. wrong but real variable name, wrong but real method). ",
    "Also assign 3 if the output is identical to the original code (no edit made) when an edit was expected.\n",
    "- Use 1-2 for cases between PARTIAL and WRONG, such as hallucinated variables or methods that don't exist.\n",
    "- WRONG (0): Broken syntax, wrong location, or completely wrong edit\n\n",
    "IMPORTANT: If the model's output is missing lines that are present in the target ",
    "(truncation) or includes extra lines not in the target, treat this as WRONG (0) ",
    "regardless of whether the intended edit is correct. ",
    "The model must reproduce the full region, not just the edit.\n\n",
    "Also tag the failure modes present. Available tags:\n",
    "- correct: output is equivalent to the target\n",
    "- truncated: output is missing lines present in the target\n",
    "- extra_lines: output includes lines not in the target\n",
    "- no_edit: output matches the original code unchanged when an edit was expected\n",
    "- wrong_name: used a wrong but real variable or function name\n",
    "- hallucinated_name: used a variable or function that does not exist\n",
    "- valid_alternative: the model's edit is defensible given the context but differs ",
    "from the target (e.g. a different but reasonable string literal, or a stylistically ",
    "different but functionally equivalent approach)\n",
    "- syntax_error: output has broken syntax\n",
    "Multiple tags can apply."
  )
}

build_sample_lookups <- function(samples) {
  ids <- samples$id
  targets <- vapply(
    seq_len(nrow(samples)),
    function(i) extract_region_text(samples$output[[i]]),
    character(1)
  )
  excerpts <- vapply(
    seq_len(nrow(samples)),
    function(i) samples$input[[i]]$excerpt,
    character(1)
  )
  variables <- lapply(
    seq_len(nrow(samples)),
    function(i) samples$input[[i]]$variables
  )
  edit_histories <- vapply(
    seq_len(nrow(samples)),
    function(i) samples$input[[i]]$edit_history %||% "",
    character(1)
  )
  list(
    targets = stats::setNames(targets, ids),
    excerpts = stats::setNames(excerpts, ids),
    variables = stats::setNames(variables, ids),
    edit_histories = stats::setNames(edit_histories, ids)
  )
}
