# Points the client at the default base URL with a fake key, so httptest2
# mocks (recorded against https://api.typesafe.ai) match.
local_ts_env <- function(env = parent.frame()) {
  withr::local_envvar(
    TYPESAFE_API_KEY = "test-key",
    TYPESAFE_BASE_URL = NA,
    .local_envir = env
  )
}

# Makes retries immediate.
local_no_backoff <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(ts_backoff = function(i) 0, .env = env)
}

json_response <- function(status = 200, body = list(), headers = list()) {
  httr2::response(
    status_code = status,
    headers = c(list("content-type" = "application/json"), headers),
    body = charToRaw(as.character(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")))
  )
}

ok_body <- function(answers = list(q = list(type = "noul", noul = 0.5))) {
  list(
    model = "jev-1.13.0",
    answers = answers,
    usage = list(input_tokens = 10, output_tokens = 2)
  )
}

spec_state <- "Help! My payouts have been failing for 3 days."
