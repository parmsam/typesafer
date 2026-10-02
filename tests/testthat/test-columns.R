quickstart <- list(
  billing = ts_noul("Is this about billing?"),
  tone = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)
quickstart_state <- "I was charged twice. Please help ASAP."

test_that("as_tibble() gives a one-row tibble of answer columns", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(quickstart_state, !!!quickstart)
  })
  out <- as_tibble(resp)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_named(out, c("billing", "tone", "tone_confidence", "urgency", "urgency_confidence"))
  expect_equal(out$billing, 0.97)
  expect_equal(out$tone, "angry")
  expect_equal(out$urgency, 1.8)

  with_probs <- as_tibble(resp, probs = TRUE)
  expect_equal(with_probs$tone_probs[[1]], c(calm = 0.1, angry = 0.9))
  expect_equal(with_probs$urgency_probs[[1]], c(0.05, 0.1, 0.85))
})

test_that("as_tibble() matches the columns system_one_df() adds", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(quickstart_state, !!!quickstart)
    df <- system_one_df(tibble::tibble(text = quickstart_state), text, !!!quickstart, probs = TRUE)
  })
  expect_equal(as_tibble(resp, probs = TRUE), df[-1])
})

test_that("as_tibble() works with no answers and validates probs", {
  empty <- ts_response(model = "m", usage = c(input_tokens = 1L, output_tokens = 1L))
  out <- as_tibble(empty)
  expect_equal(dim(out), c(1L, 0L))
  expect_error(as_tibble(empty, probs = NA), class = "typesafer_error_input")
})

test_that("include_usage adds token columns", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(quickstart_state, !!!quickstart)
    df <- system_one_df(tibble::tibble(text = quickstart_state), text, !!!quickstart, include_usage = TRUE)
  })
  out <- as_tibble(resp, include_usage = TRUE)
  expect_equal(out$input_tokens, 350L)
  expect_equal(out$output_tokens, 45L)
  expect_equal(tail(names(df), 2), c("input_tokens", "output_tokens"))
  expect_equal(df$input_tokens, 350L)
  expect_equal(as_tibble(resp, include_usage = TRUE), df[-1])
  expect_error(as_tibble(resp, include_usage = "yes"), class = "typesafer_error_input")
})

test_that("include_usage is NA for failed rows and checked for clashes", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) {
    if (jsonlite::fromJSON(req$body$data)$state == "bad") {
      json_response(422, list(detail = list()))
    } else {
      json_response(body = ok_body())
    }
  })
  df <- data.frame(s = c("ok", "bad"))
  out <- suppressWarnings(
    system_one_df(df, s, q = ts_noul("?"), include_usage = TRUE, on_error = "continue")
  )
  expect_equal(out$input_tokens, c(10L, NA))
  expect_equal(out$output_tokens, c(2L, NA))

  clash <- data.frame(s = "x", input_tokens = 1)
  expect_error(
    system_one_df(clash, s, q = ts_noul("?"), include_usage = TRUE),
    class = "typesafer_error_input"
  )
  expect_error(
    system_one_df(df, s, q = ts_noul("?"), include_usage = NA),
    class = "typesafer_error_input"
  )
})
