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

#' Get the default model
#'
#' Reads the `TYPESAFE_DEFAULT_MODEL` environment variable (the same variable
#' the Python SDK uses), falling back to `"jev-latest"`. Set it to pin a
#' versioned model such as `"jev-1.13.0"` for every call without passing
#' `model` each time.
#'
#' @returns The model name, a string.
#' @export
#' @examples
#' ts_default_model()
ts_default_model <- function() {
  model <- Sys.getenv("TYPESAFE_DEFAULT_MODEL")
  if (nzchar(model)) model else "jev-latest"
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

ts_request <- function(path, api_key, max_tries = 3, timeout = ts_timeout()) {
  req <- httr2::request(ts_base_url())
  req <- httr2::req_url_path_append(req, path)
  req <- httr2::req_auth_bearer_token(req, api_key)
  req <- httr2::req_headers(req, Accept = "application/json")
  req <- httr2::req_user_agent(req, ts_user_agent())
  req <- httr2::req_timeout(req, timeout)
  httr2::req_retry(
    req,
    max_tries = max_tries,
    max_seconds = 30,
    retry_on_failure = TRUE,
    is_transient = ts_is_transient,
    backoff = ts_backoff,
    after = ts_retry_after
  )
}

ts_timeout <- function() {
  getOption("typesafer.timeout", 10)
}

check_retry_args <- function(max_tries, timeout, call = rlang::caller_env()) {
  if (!rlang::is_scalar_integerish(max_tries) || is.na(max_tries) || max_tries < 1) {
    abort_input("{.arg max_tries} must be a whole number of at least 1.", call = call)
  }
  if (!(is.numeric(timeout) && length(timeout) == 1 && is.finite(timeout) && timeout > 0)) {
    abort_input("{.arg timeout} must be a positive number of seconds.", call = call)
  }
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

ts_perform <- function(req, api_key = NULL, call = rlang::caller_env()) {
  resp <- tryCatch(
    httr2::req_perform(req),
    httr2_error = function(cnd) {
      rlang::cnd_signal(as_typesafer_cnd(cnd, api_key = api_key, call = call))
    }
  )
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}
