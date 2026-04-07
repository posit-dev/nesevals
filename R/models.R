#' Model endpoint URLs
#'
#' @description
#' Retrieve the endpoint URL for a given model. URLs are read from environment
#' variables so that they do not need to be stored in the package source.
#'
#' The expected environment variables are:
#'
#' * `NESEVALS_ZETA_URL` -- endpoint URL for the Zeta model
#' * `NESEVALS_QWEN3_8B_URL` -- endpoint URL for the Qwen3-8B model
#' * `NESEVALS_GEMMA4_26B_A4B_URL` -- endpoint URL for the Gemma 4 26B A4B model
#' * `NESEVALS_GEMMA4_26B_A4B_FP8_URL` -- endpoint URL for the Gemma 4 26B A4B
#'   FP8 model
#'
#' A convenient place to set these is your `.Renviron` file (see
#' [usethis::edit_r_environ()]).
#'
#' The endpoints will go to sleep after 15 minutes. As you begin working on
#' features that will use these models, you may want to ping the endpoints
#' to wake the instance up (it will take a few minutes).
#'
#' @param model Character. One of `"zeta"`, `"qwen3-8b"`,
#'   `"gemma4-26b-a4b"`, or `"gemma4-26b-a4b-fp8"`.
#'
#' @returns A single character string: the endpoint URL.
#'
#' @examples
#' \dontrun{
#' model_url("zeta")
#' model_url("qwen3-8b")
#' model_url("gemma4-26b-a4b")
#' model_url("gemma4-26b-a4b-fp8")
#' }
#'
#' @keywords internal
model_url <- function(model = c("qwen3-8b", "zeta", "gemma4-26b-a4b", "gemma4-26b-a4b-fp8")) {
  model <- match.arg(model)

  env_var <- switch(
    model,
    "zeta" = "NESEVALS_ZETA_URL",
    "qwen3-8b" = "NESEVALS_QWEN3_8B_URL",
    "gemma4-26b-a4b" = "NESEVALS_GEMMA4_26B_A4B_URL",
    "gemma4-26b-a4b-fp8" = "NESEVALS_GEMMA4_26B_A4B_FP8_URL"
  )

  url <- Sys.getenv(env_var)
  if (!nzchar(url)) {
    cli::cli_abort(
      "The {.envvar {env_var}} environment variable is not set.
       Set it in your {.file .Renviron} (see {.fn usethis::edit_r_environ})."
    )
  }

  url
}
