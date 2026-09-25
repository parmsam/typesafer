abort_input <- function(message, ...,
                        call = rlang::caller_env(),
                        .envir = parent.frame()) {
  cli::cli_abort(
    message,
    ...,
    .envir = .envir,
    class = c("typesafer_error_input", "typesafer_error"),
    call = call
  )
}

# JSON content accepted by the API for `state`, `instructions`, and
# descriptions: a single string, or a list (object or array).
is_json_content <- function(x) {
  rlang::is_string(x) || is.list(x)
}

is_json_content_or_null <- function(x) {
  is.null(x) || is_json_content(x)
}

ts_json <- function(x) {
  jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  )
}
