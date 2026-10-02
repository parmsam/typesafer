call_with_response <- function(resp) {
  httr2::local_mocked_responses(function(req) resp)
  system_one("x", q = ts_noul("?"))
}

test_that("missing API key is a typesafer_error_auth", {
  withr::local_envvar(TYPESAFE_API_KEY = NA)
  expect_error(ts_api_key(), class = "typesafer_error_auth")
  expect_error(system_one("x", q = ts_noul("?")), class = "typesafer_error_auth")
  expect_snapshot(ts_api_key(), error = TRUE)
  expect_error(system_one("x", q = ts_noul("?"), api_key = ""), class = "typesafer_error_auth")
})

test_that("ts_api_key() reads TYPESAFE_API_KEY", {
  withr::local_envvar(TYPESAFE_API_KEY = "abc")
  expect_equal(ts_api_key(), "abc")
})

test_that("401 is a typesafer_error_auth", {
  local_ts_env()
  resp <- json_response(401, list(detail = "Invalid API key"), list("x-typesafe-request-id" = "req_123"))
  err <- expect_error(call_with_response(resp), class = "typesafer_error_auth")
  expect_s3_class(err, "typesafer_error_http")
  expect_s3_class(err, "typesafer_error")
  expect_equal(err$status, 401L)
  expect_equal(err$request_id, "req_123")
  expect_equal(err$response_body, list(detail = "Invalid API key"))
  expect_snapshot(call_with_response(resp), error = TRUE)
})

test_that("401 hint points at where the key came from", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) json_response(401, list(detail = "bad key")))

  err <- expect_error(system_one("x", q = ts_noul("?")), class = "typesafer_error_auth")
  expect_match(conditionMessage(err), "TYPESAFE_API_KEY", fixed = TRUE)

  err <- expect_error(system_one("x", q = ts_noul("?"), api_key = "other-key"), class = "typesafer_error_auth")
  expect_match(conditionMessage(err), "passed to `api_key`", fixed = TRUE)
  expect_no_match(conditionMessage(err), "TYPESAFE_API_KEY", fixed = TRUE)

  df <- data.frame(s = "x")
  err <- expect_error(system_one_df(df, s, q = ts_noul("?"), api_key = "other-key"), class = "typesafer_error_auth")
  expect_match(conditionMessage(err), "passed to `api_key`", fixed = TRUE)

  expect_match(auth_hint(NULL), "defaults to the `TYPESAFE_API_KEY`", fixed = TRUE)
})

test_that("422 is a typesafer_error_validation with field details", {
  local_ts_env()
  resp <- json_response(422, list(detail = list(
    # Shape returned by the live API: the question type tag follows the id.
    list(loc = list("body", "questions", "tone", "choice", "criteria"), msg = "Field required", type = "missing"),
    list(loc = list("body", "questions", "urgency", "score", "criteria", 0L), msg = "Input should be a valid string", type = "string_type"),
    list(loc = list("body", "state"), msg = "Field required", type = "missing")
  )))
  err <- expect_error(call_with_response(resp), class = "typesafer_error_validation")
  expect_s3_class(err, "typesafer_error_http")
  expect_equal(err$status, 422L)
  expect_equal(err$details$field, c("questions.tone.criteria", "questions.urgency.criteria.0", "state"))
  expect_equal(err$details$message, c("Field required", "Input should be a valid string", "Field required"))
  expect_equal(err$details$type, c("missing", "string_type", "missing"))
  expect_snapshot(call_with_response(resp), error = TRUE)
})

test_that("422 without a detail list falls back to the server message", {
  local_ts_env()
  resp <- json_response(422, list(message = "state is too long"))
  err <- expect_error(call_with_response(resp), class = "typesafer_error_validation")
  expect_equal(nrow(err$details), 0)
  expect_match(conditionMessage(err), "state is too long")
})

test_that("429 and 529 are typesafer_error_rate_limit after retries", {
  local_ts_env()
  local_no_backoff()
  err <- expect_error(
    call_with_response(json_response(429, list(error = "Too many requests"))),
    class = "typesafer_error_rate_limit"
  )
  expect_s3_class(err, "typesafer_error_http")
  expect_equal(err$status, 429L)

  err <- expect_error(
    call_with_response(json_response(529, list(error = list(message = "Overloaded")))),
    class = "typesafer_error_rate_limit"
  )
  expect_equal(err$status, 529L)
  expect_snapshot(call_with_response(json_response(529, list(error = list(message = "Overloaded")))), error = TRUE)
})

test_that("other 5xx are typesafer_error_server", {
  local_ts_env()
  local_no_backoff()
  err <- expect_error(
    call_with_response(httr2::response(500, body = charToRaw("upstream exploded"))),
    class = "typesafer_error_server"
  )
  expect_s3_class(err, "typesafer_error_http")
  expect_equal(err$response_body, "upstream exploded")
  expect_false(inherits(err, "typesafer_error_rate_limit"))
})

test_that("other 4xx are plain typesafer_error_http", {
  local_ts_env()
  err <- expect_error(call_with_response(httr2::response(404)), class = "typesafer_error_http")
  expect_null(err$response_body)
  expect_equal(
    setdiff(class(err), c("rlang_error", "error", "condition")),
    c("typesafer_error_http", "typesafer_error")
  )
  expect_snapshot(call_with_response(httr2::response(404)), error = TRUE)
})

test_that("connection failures are typesafer_error_connection", {
  local_no_backoff()
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = "http://127.0.0.1:9")
  withr::local_options(typesafer.timeout = 2)
  err <- expect_error(system_one("x", q = ts_noul("?")), class = "typesafer_error_connection")
  expect_s3_class(err, "typesafer_error")
  expect_s3_class(err$parent, "httr2_failure")
})

test_that("server_message() mirrors the Python SDK", {
  expect_equal(server_message("boom"), "boom")
  expect_null(server_message(""))
  expect_equal(server_message(list(error = "e")), "e")
  expect_equal(server_message(list(error = list(message = "em"))), "em")
  expect_equal(server_message(list(message = "m")), "m")
  expect_equal(server_message(list(detail = "d")), "d")
  expect_equal(server_message(list(detail = list(message = "dm"))), "dm")
  expect_null(server_message(list(other = 1)))
  expect_null(server_message(NULL))
})
