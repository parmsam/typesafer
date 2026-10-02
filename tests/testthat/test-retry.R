test_that("retry policy matches the Python SDK defaults", {
  req <- ts_request("v1/systemone", "k")
  expect_equal(req$policies$retry_max_tries, 3)
  expect_equal(req$policies$retry_max_wait, 30)
  expect_true(req$policies$retry_on_failure)

  transient <- function(status) ts_is_transient(httr2::response(status))
  expect_true(all(vapply(c(408, 429, 500, 502, 503, 504, 529), transient, logical(1))))
  expect_false(any(vapply(c(400, 401, 403, 404, 422), transient, logical(1))))
})

test_that("backoff doubles from 0.5s up to 5s with at most 25% jitter", {
  withr::local_seed(1)
  for (i in 1:6) {
    cap <- min(0.5 * 2^(i - 1), 5)
    delays <- replicate(50, ts_backoff(i))
    expect_true(all(delays <= cap & delays >= 0.75 * cap))
  }
})

test_that("retry-after-ms takes precedence over retry-after", {
  expect_equal(ts_retry_after(httr2::response(429, headers = list("retry-after-ms" = "250"))), 0.25)
  expect_equal(
    ts_retry_after(httr2::response(429, headers = list("retry-after-ms" = "250", "retry-after" = "9"))),
    0.25
  )
  expect_equal(ts_retry_after(httr2::response(429, headers = list("retry-after" = "2"))), 2)
  expect_equal(ts_retry_after(httr2::response(429, headers = list("retry-after-ms" = "soon", "retry-after" = "2"))), 2)
  expect_true(is.na(ts_retry_after(httr2::response(429))))
})

# httr2's mocking bypasses its retry loop, so exercise retries against a real
# local server.
retry_app <- function() {
  app <- webfakes::new_app()
  app$locals$attempts <- list()
  answer <- '{"model":"jev-1.13.0","answers":{"q":{"type":"noul","noul":0.5}},"usage":{"input_tokens":1,"output_tokens":1}}'

  # Fails with 429, then 503, then succeeds. Each state gets its own counter so
  # parallel requests are independent.
  app$post("/flaky/v1/systemone", function(req, res) {
    state <- jsonlite::fromJSON(rawToChar(req$.body))$state
    n <- (app$locals$attempts[[state]] %||% 0) + 1
    app$locals$attempts[[state]] <- n
    if (n == 1) {
      return(res$set_status(429)$set_header("retry-after-ms", "0")$send_json(list(error = "slow down"), auto_unbox = TRUE))
    }
    if (n == 2) {
      return(res$set_status(503)$send_json(list(error = "unavailable"), auto_unbox = TRUE))
    }
    res$set_header("x-attempts", n)$send_json(text = answer)
  })

  app$post("/limited/v1/systemone", function(req, res) {
    app$locals$limited <- (app$locals$limited %||% 0) + 1
    res$set_status(429)$
      set_header("retry-after", "0")$
      set_header("x-attempts", app$locals$limited)$
      send_json(list(error = "Rate limit exceeded"), auto_unbox = TRUE)
  })

  app$post("/invalid/v1/systemone", function(req, res) {
    app$locals$invalid <- (app$locals$invalid %||% 0) + 1
    res$set_status(422)$
      set_header("x-attempts", app$locals$invalid)$
      send_json(list(detail = list(list(loc = list("body", "state"), msg = "bad", type = "x"))), auto_unbox = TRUE)
  })
  app
}

test_that("429 and 5xx are retried until success", {
  skip_if_not_installed("webfakes")
  local_no_backoff()
  srv <- webfakes::local_app_process(retry_app())
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = srv$url("/flaky"))

  resp <- system_one("single", q = ts_noul("?"))
  expect_equal(resp@answers$q@prob, 0.5)
})

test_that("retries give up after 3 attempts", {
  skip_if_not_installed("webfakes")
  local_no_backoff()
  srv <- webfakes::local_app_process(retry_app())
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = srv$url("/limited"))

  err <- expect_error(system_one("x", q = ts_noul("?")), class = "typesafer_error_rate_limit")
  expect_equal(httr2::resp_header(err$resp, "x-attempts"), "3")
})

test_that("422 is not retried", {
  skip_if_not_installed("webfakes")
  local_no_backoff()
  srv <- webfakes::local_app_process(retry_app())
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = srv$url("/invalid"))

  err <- expect_error(system_one("x", q = ts_noul("?")), class = "typesafer_error_validation")
  expect_equal(httr2::resp_header(err$resp, "x-attempts"), "1")
})

test_that("parallel requests in system_one_df() are retried", {
  skip_if_not_installed("webfakes")
  local_no_backoff()
  srv <- webfakes::local_app_process(retry_app())
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = srv$url("/flaky"))

  out <- system_one_df(data.frame(s = c("r1", "r2", "r3")), s, q = ts_noul("?"), max_active = 2)
  expect_equal(out$q, c(0.5, 0.5, 0.5))
})

test_that("max_tries and timeout are passed to each request", {
  local_ts_env()
  seen <- list()
  httr2::local_mocked_responses(function(req) {
    seen[[length(seen) + 1]] <<- req
    if (grepl("models", req$url)) json_response(body = list(models = list())) else json_response(body = ok_body())
  })
  system_one("x", q = ts_noul("?"), max_tries = 5, timeout = 2.5)
  system_one_df(data.frame(s = "x"), s, q = ts_noul("?"), max_tries = 1, timeout = 7)
  ts_models(max_tries = 4, timeout = 3)

  expect_equal(seen[[1]]$policies$retry_max_tries, 5)
  expect_equal(seen[[1]]$options$timeout_ms, 2500)
  expect_equal(seen[[2]]$policies$retry_max_tries, 1)
  expect_equal(seen[[2]]$options$timeout_ms, 7000)
  expect_equal(seen[[3]]$policies$retry_max_tries, 4)
  expect_equal(seen[[3]]$options$timeout_ms, 3000)
})

test_that("timeout defaults to the typesafer.timeout option", {
  local_ts_env()
  withr::local_options(typesafer.timeout = 42)
  seen <- NULL
  httr2::local_mocked_responses(function(req) {
    seen <<- req
    json_response(body = ok_body())
  })
  system_one("x", q = ts_noul("?"))
  expect_equal(seen$options$timeout_ms, 42000)
  expect_equal(seen$policies$retry_max_tries, 3)
})

test_that("max_tries and timeout are validated", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) stop("should not be called"))
  for (bad in list(0, 1.5, NA, "3", c(2, 3))) {
    expect_error(system_one("x", q = ts_noul("?"), max_tries = bad), class = "typesafer_error_input")
  }
  for (bad in list(0, -1, NA_real_, Inf, "10", c(1, 2))) {
    expect_error(system_one("x", q = ts_noul("?"), timeout = bad), class = "typesafer_error_input")
  }
  expect_error(system_one_df(data.frame(s = "x"), s, q = ts_noul("?"), max_tries = 0), class = "typesafer_error_input")
  expect_error(ts_models(timeout = 0), class = "typesafer_error_input")
})

test_that("max_tries = 1 disables retries", {
  skip_if_not_installed("webfakes")
  local_no_backoff()
  srv <- webfakes::local_app_process(retry_app())
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = srv$url("/limited"))

  err <- expect_error(system_one("x", q = ts_noul("?"), max_tries = 1), class = "typesafer_error_rate_limit")
  expect_equal(httr2::resp_header(err$resp, "x-attempts"), "1")
})
