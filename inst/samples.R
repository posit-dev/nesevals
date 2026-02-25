library(jsonlite)

sample_files <- list.files(
  "inst/samples",
  pattern = "\\.json$",
  full.names = TRUE
)

sample_list <- lapply(sample_files, function(f) {
  fromJSON(f, simplifyVector = FALSE)
})

samples <- data.frame(
  id = tools::file_path_sans_ext(basename(sample_files)),
  output = vapply(sample_list, function(x) x$output, character(1)),
  stringsAsFactors = FALSE
)

samples$input <- lapply(sample_list, function(x) x$input)
samples$tags <- lapply(sample_list, function(x) x$tags)

samples <- samples[, c("id", "input", "output", "tags")]

usethis::use_data(samples, overwrite = TRUE)
