#' Errors
#'
#' @description
#' Every error raised by typesafer inherits from `typesafer_error`, so you can
#' catch them all with `tryCatch(..., typesafer_error = ...)`. More specific
#' classes:
#'
#' * `typesafer_error_input`: invalid arguments, detected before any request
#'   is sent.
#' * `typesafer_error_auth`: the API key is missing, or the API rejected it
#'   (HTTP 401).
#' * `typesafer_error_http`: any unsuccessful HTTP response. Has fields
#'   `status`, `response_body` (parsed JSON, text, or `NULL`), `request_id`,
#'   and `resp` (the [httr2::response()]). Subclasses:
#'   * `typesafer_error_auth`: HTTP 401.
#'   * `typesafer_error_validation`: HTTP 422. The `details` field is a tibble
#'     with one row per offending field (`field`, `message`, `type`).
#'   * `typesafer_error_rate_limit`: HTTP 429 (rate limited) or 529
#'     (overloaded), after retries are exhausted.
#'   * `typesafer_error_server`: other 5xx responses, after retries are
#'     exhausted.
#' * `typesafer_error_connection`: the request never got a response (DNS,
#'   connection, or timeout failure), after retries are exhausted.
#'
#' Requests that fail with 408, 429, or 5xx, or with a connection failure, are
#' retried up to twice with exponential backoff (0.5s doubling to at most 5s,
#' with jitter), within a 30 second budget. `retry-after-ms` and `retry-after`
#' response headers are honored.
#'
#' @name typesafer_error
#' @examples
#' tryCatch(
#'   ts_score("How urgent?", "high"),
#'   typesafer_error_input = function(e) conditionMessage(e)
#' )
NULL

http_error_classes <- function(status) {
  specific <- if (status == 401) {
    "typesafer_error_auth"
  } else if (status == 422) {
    "typesafer_error_validation"
  } else if (status %in% c(429, 529)) {
    "typesafer_error_rate_limit"
  } else if (status >= 500) {
    "typesafer_error_server"
  }
  c(specific, "typesafer_error_http", "typesafer_error")
}

resp_body_safely <- function(resp) {
  if (!httr2::resp_has_body(resp)) {
    return(NULL)
  }
  text <- httr2::resp_body_string(resp)
  tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(e) text
  )
}

# Mirrors the Python SDK's extraction of a server message from an error body.
server_message <- function(body) {
  if (rlang::is_string(body)) {
    return(if (nzchar(body)) body)
  }
  if (!is.list(body)) {
    return(NULL)
  }
  field <- function(x, name) if (is.list(x)) x[[name]]
  candidates <- list(
    body$error,
    field(body$error, "message"),
    body$message,
    body$detail,
    field(body$detail, "message")
  )
  for (x in candidates) {
    if (rlang::is_string(x)) {
      return(x)
    }
  }
  NULL
}

validation_details <- function(body) {
  detail <- if (is.list(body)) body$detail
  entries <- Filter(function(x) is.list(x) && rlang::is_string(x$msg), detail %||% list())
  field <- vapply(entries, function(x) {
    loc <- unlist(x$loc)
    loc <- loc[loc != "body"]
    # The API includes the question's type tag after its id
    # (questions.<id>.<type>.criteria); drop it, as the Python SDK does.
    if (length(loc) >= 3 && loc[[1]] == "questions" && loc[[3]] %in% c("noul", "choice", "score")) {
      loc <- loc[-3]
    }
    paste(loc, collapse = ".")
  }, character(1))
  tibble::tibble(
    field = field,
    message = vapply(entries, function(x) x$msg, character(1)),
    type = vapply(entries, function(x) x$type %||% NA_character_, character(1))
  )
}

# `api_key` is the key the request was sent with, used to point a 401 at the
# right place: the environment variable or the `api_key` argument.
http_error_cnd <- function(resp, api_key = NULL, call = rlang::caller_env()) {
  status <- httr2::resp_status(resp)
  body <- resp_body_safely(resp)
  request_id <- httr2::resp_header(resp, "x-typesafe-request-id")
  classes <- http_error_classes(status)
  details <- NULL

  header <- switch(
    classes[[1]],
    typesafer_error_auth = "TypeSafe API rejected the API key (HTTP 401).",
    typesafer_error_validation = "TypeSafe API rejected the request as invalid (HTTP 422).",
    typesafer_error_rate_limit = if (status == 529) {
      "TypeSafe API is overloaded (HTTP 529)."
    } else {
      "TypeSafe API rate limit exceeded (HTTP 429)."
    },
    typesafer_error_server = sprintf("TypeSafe API server error (HTTP %d).", status),
    sprintf("TypeSafe API request failed (HTTP %d %s).", status, httr2::resp_status_desc(resp) %||% "")
  )

  bullets <- character()
  if (status == 422) {
    details <- validation_details(body)
    if (nrow(details) > 0) {
      bullets <- rlang::set_names(
        ifelse(nzchar(details$field), paste0(details$field, ": ", details$message), details$message),
        "x"
      )
    }
  }
  if (length(bullets) == 0) {
    msg <- server_message(body)
    if (!is.null(msg)) {
      bullets <- c(x = msg)
    }
  }
  if (status == 401) {
    bullets <- c(bullets, i = auth_hint(api_key))
  }
  if (status %in% c(429, 529)) {
    bullets <- c(bullets, i = "Retries with backoff were exhausted; wait before trying again.")
  }
  if (!is.null(request_id)) {
    bullets <- c(bullets, i = paste0("Request ID: ", request_id))
  }

  rlang::error_cnd(
    class = classes,
    message = header,
    body = if (length(bullets) > 0) rlang::format_error_bullets(bullets),
    call = call,
    status = status,
    response_body = body,
    request_id = request_id,
    details = details,
    resp = resp
  )
}

auth_hint <- function(api_key) {
  env_key <- Sys.getenv("TYPESAFE_API_KEY")
  if (is.null(api_key)) {
    "Check your API key: the `api_key` argument, which defaults to the `TYPESAFE_API_KEY` environment variable."
  } else if (nzchar(env_key) && identical(api_key, env_key)) {
    "Check the key in the `TYPESAFE_API_KEY` environment variable."
  } else {
    "Check the key passed to `api_key`."
  }
}

connection_error_cnd <- function(parent, call = rlang::caller_env()) {
  rlang::error_cnd(
    class = c("typesafer_error_connection", "typesafer_error"),
    message = "Failed to reach the TypeSafe API.",
    call = call,
    parent = parent
  )
}

# Converts an httr2 error into the matching typesafer condition.
as_typesafer_cnd <- function(cnd, api_key = NULL, call = rlang::caller_env()) {
  if (inherits(cnd, "httr2_http")) {
    http_error_cnd(cnd$resp, api_key = api_key, call = call)
  } else if (inherits(cnd, "httr2_failure")) {
    connection_error_cnd(cnd, call = call)
  } else {
    cnd
  }
}
