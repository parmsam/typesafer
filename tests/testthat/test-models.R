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

test_that("ts_default_model() reads TYPESAFE_DEFAULT_MODEL", {
  withr::local_envvar(TYPESAFE_DEFAULT_MODEL = NA)
  expect_equal(ts_default_model(), "jev-latest")
  withr::local_envvar(TYPESAFE_DEFAULT_MODEL = "")
  expect_equal(ts_default_model(), "jev-latest")
  withr::local_envvar(TYPESAFE_DEFAULT_MODEL = "jev-1.13.0")
  expect_equal(ts_default_model(), "jev-1.13.0")
})

test_that("system_one() and system_one_df() use the default model", {
  local_ts_env()
  withr::local_envvar(TYPESAFE_DEFAULT_MODEL = "jev-1.13.0")
  models <- character()
  httr2::local_mocked_responses(function(req) {
    models <<- c(models, jsonlite::fromJSON(req$body$data)$model)
    json_response(body = ok_body())
  })
  system_one("x", q = ts_noul("?"))
  system_one_df(data.frame(s = c("a", "b")), s, q = ts_noul("?"))
  system_one("x", q = ts_noul("?"), model = "jev-preview")
  expect_equal(models[1], "jev-1.13.0")
  expect_setequal(models[2:3], "jev-1.13.0")
  expect_equal(models[4], "jev-preview")
})
