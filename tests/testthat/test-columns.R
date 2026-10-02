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
