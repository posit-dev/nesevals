# Build the `results` dataset from inst/results/ JSON files.
#
# Run this script from the package root to regenerate data/results.rda:
#   source("data-raw/results.R")

library(jsonlite)

pkg_root <- rprojroot::find_package_root_file()
results_dir <- file.path(pkg_root, "inst", "results")

config_names <- tools::file_path_sans_ext(
  list.files(file.path(results_dir, "completions"))
)

rows <- lapply(config_names, function(cfg) {
  comp <- fromJSON(
    file.path(results_dir, "completions", paste0(cfg, ".json")),
    simplifyDataFrame = FALSE
  )
  scores <- fromJSON(
    file.path(results_dir, "scores", paste0(cfg, ".json")),
    simplifyDataFrame = FALSE
  )
  meta <- fromJSON(
    file.path(results_dir, "metadata", paste0(cfg, ".json")),
    simplifyDataFrame = FALSE
  )

  n_total <- length(comp)
  n_processable <- sum(vapply(scores, function(s) isTRUE(s$processable), logical(1)))
  n_exact <- sum(vapply(scores, function(s) isTRUE(s$exact_match), logical(1)))

  # Mean score: 0 for non-processable completions
  all_scores <- vapply(
    scores,
    function(s) if (isTRUE(s$processable)) s$score else 0L,
    double(1)
  )

  latencies_ms <- vapply(
    comp,
    function(x) if (!is.null(x$latency)) x$latency * 1000 else NA_real_,
    double(1)
  )

  input_tokens <- vapply(
    comp,
    function(x) if (!is.null(x$tokens_input)) as.double(x$tokens_input) else NA_real_,
    double(1)
  )

  output_tokens <- vapply(
    comp,
    function(x) if (!is.null(x$tokens_output)) as.double(x$tokens_output) else NA_real_,
    double(1)
  )

  data.frame(
    model = meta$model,
    prompt = meta$prompt,
    edit_history = meta$edit_history_format,
    output_format = meta$output_format,
    n_completions = n_total,
    n_processable = n_processable,
    n_exact = n_exact,
    mean_score = round(mean(all_scores), 2),
    median_latency_ms = round(median(latencies_ms, na.rm = TRUE)),
    mean_input_tokens = round(mean(input_tokens, na.rm = TRUE)),
    mean_output_tokens = round(mean(output_tokens, na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
})

nes_results <- do.call(rbind, rows)
nes_results <- nes_results[order(-nes_results$mean_score), ]
rownames(nes_results) <- NULL

usethis::use_data(nes_results, overwrite = TRUE)
