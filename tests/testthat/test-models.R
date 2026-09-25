test_that("ts_models() returns a tibble of models", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    models <- ts_models()
  })
  expect_s3_class(models, "tbl_df")
  expect_named(models, c("name", "description", "release_date"))
  expect_equal(models$name, c("jev-latest", "jev-preview"))
  expect_equal(models$release_date, as.Date(c("2026-09-15", "2026-09-15")))
})

test_that("ts_models() sends GET /v1/models", {
  local_ts_env()
  seen <- NULL
  httr2::local_mocked_responses(function(req) {
    seen <<- req
    json_response(body = list(models = list()))
  })
  models <- ts_models()
  expect_equal(seen$url, "https://api.typesafe.ai/v1/models")
  expect_equal(httr2::req_get_method(seen), "GET")
  expect_equal(nrow(models), 0)
})

test_that("ts_models() raises classed errors", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) json_response(401, list(detail = "bad key")))
  expect_error(ts_models(), class = "typesafer_error_auth")
})
