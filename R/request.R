#' Get the TypeSafe API key
#'
#' Reads the `TYPESAFE_API_KEY` environment variable. Set it in your
#' `.Renviron` (for example with `usethis::edit_r_environ()`) rather than in
#' code.
#'
#' @returns The API key, a string.
#' @export
#' @examples
#' \dontrun{
#' ts_api_key()
#' }
ts_api_key <- function() {
  key <- Sys.getenv("TYPESAFE_API_KEY")
  if (!nzchar(key)) {
    cli::cli_abort(
      c(
        "No TypeSafe API key found.",
        i = "Set the {.envvar TYPESAFE_API_KEY} environment variable, e.g. in {.file ~/.Renviron}."
      ),
      class = c("typesafer_error_auth", "typesafer_error")
    )
  }
  key
}

ts_base_url <- function() {
  url <- Sys.getenv("TYPESAFE_BASE_URL")
  if (!nzchar(url)) {
    url <- "https://api.typesafe.ai"
  }
  sub("/+$", "", url)
}

ts_user_agent <- function() {
  paste0(
    "typesafer/", utils::packageVersion("typesafer"),
    " (R ", getRversion(), ")"
  )
}

check_api_key <- function(api_key, call = rlang::caller_env()) {
  if (!rlang::is_string(api_key) || !nzchar(api_key)) {
    cli::cli_abort(
      "{.arg api_key} must be a non-empty string.",
      class = c("typesafer_error_auth", "typesafer_error"),
      call = call
    )
  }
}

ts_request <- function(path, api_key) {
  req <- httr2::request(ts_base_url())
  req <- httr2::req_url_path_append(req, path)
  req <- httr2::req_auth_bearer_token(req, api_key)
  req <- httr2::req_headers(req, Accept = "application/json")
  req <- httr2::req_user_agent(req, ts_user_agent())
  req <- httr2::req_timeout(req, getOption("typesafer.timeout", 10))
  httr2::req_retry(
    req,
    max_tries = 3,
    max_seconds = 30,
    retry_on_failure = TRUE,
    is_transient = ts_is_transient,
    backoff = ts_backoff,
    after = ts_retry_after
  )
}

ts_req_body <- function(req, data) {
  httr2::req_body_raw(req, as.character(ts_json(data)), type = "application/json")
}

# Retry policy, matching the Python SDK defaults -------------------------------

ts_is_transient <- function(resp) {
  httr2::resp_status(resp) %in% c(408L, 429L, 500:599)
}

ts_backoff <- function(i) {
  delay <- min(0.5 * 2^(i - 1), 5)
  delay * (1 - stats::runif(1) * 0.25)
}

ts_retry_after <- function(resp) {
  ms <- httr2::resp_header(resp, "retry-after-ms")
  if (!is.null(ms)) {
    value <- suppressWarnings(as.numeric(ms))
    if (is.finite(value) && value >= 0) {
      return(value / 1000)
    }
  }
  httr2::resp_retry_after(resp)
}

# Performing ------------------------------------------------------------------

ts_perform <- function(req, call = rlang::caller_env()) {
  resp <- tryCatch(
    httr2::req_perform(req),
    httr2_error = function(cnd) {
      rlang::cnd_signal(as_typesafer_cnd(cnd, call = call))
    }
  )
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}
