#' List available models
#'
#' Calls `GET /v1/models`, which lists the model names your account can send
#' in the `model` argument. It currently lists the aliases (such as
#' `"jev-latest"`); versioned IDs such as `"jev-1.13.0"` are accepted whether
#' or not they're listed. See <https://docs.typesafe.ai/models>.
#'
#' @inheritParams system_one
#' @returns A tibble with columns `name`, `description`, and `release_date`
#'   (a Date).
#' @export
#' @examples
#' \dontrun{
#' ts_models()
#' }
ts_models <- function(max_tries = 3, timeout = ts_timeout(), api_key = ts_api_key()) {
  check_retry_args(max_tries, timeout)
  check_api_key(api_key)
  req <- ts_request("v1/models", api_key, max_tries = max_tries, timeout = timeout)
  body <- ts_perform(req, api_key = api_key)
  models <- body$models %||% list()
  chr <- function(field) {
    vapply(models, function(m) as.character(m[[field]] %||% NA_character_), character(1))
  }
  tibble::tibble(
    name = chr("name"),
    description = chr("description"),
    release_date = as.Date(chr("release_date"))
  )
}
