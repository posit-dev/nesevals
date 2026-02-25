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
#'
#' A convenient place to set these is your `.Renviron` file (see
#' [usethis::edit_r_environ()]).
#'
#' The endpoints will go to sleep after 15 minutes. As you begin working on
#' features that will use these models, you may want to ping the endpoints
#' to wake the instance up (it will take a few minutes).
#'
#' @param model Character. One of `"zeta"` or `"qwen3-8b"`.
#'
#' @returns A single character string: the endpoint URL.
#'
#' @examples
#' \dontrun{
#' model_url("zeta")
#' model_url("qwen3-8b")
#' }
#'
#' @export
model_url <- function(model = c("qwen3-8b", "zeta")) {
  model <- match.arg(model)

  env_var <- switch(
    model,
    "zeta" = "NESEVALS_ZETA_URL",
    "qwen3-8b" = "NESEVALS_QWEN3_8B_URL"
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
