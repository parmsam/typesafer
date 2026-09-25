tickets <- tibble::tibble(
  id = 1:3,
  text = c(
    "I was charged twice. Please help ASAP.",
    "How do I export my data to CSV?",
    "Your app crashed and I lost an hour of work!!"
  )
)

quickstart <- list(
  billing = ts_noul("Is this about billing?"),
  tone = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)

test_that("adds typed columns per question type", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    out <- system_one_df(tickets, state = text, !!!quickstart)
  })
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("id", "text", "billing", "tone", "tone_confidence", "urgency", "urgency_confidence"))
  expect_equal(out$id, 1:3)
  expect_equal(out$billing, c(0.97, 0.02, 0.05))
  expect_equal(out$tone, c("angry", "calm", "angry"))
  expect_equal(out$tone_confidence, c(0.7, 0.7, 0.7))
  expect_equal(out$urgency, c(1.8, 0.3, 1.6))
  expect_equal(out$urgency_confidence, c(0.8, 0.8, 0.8))
})

test_that("probs = TRUE adds probability list-columns", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    out <- system_one_df(tickets, state = text, !!!quickstart, probs = TRUE)
  })
  expect_named(out, c(
    "id", "text", "billing", "tone", "tone_confidence", "tone_probs",
    "urgency", "urgency_confidence", "urgency_probs"
  ))
  expect_equal(out$tone_probs[[2]], c(calm = 0.95, angry = 0.05))
  expect_equal(out$urgency_probs[[1]], c(0.05, 0.1, 0.85))
})

test_that("works with plain data frames and state expressions", {
  local_ts_env()
  df <- data.frame(a = "I was charged twice.", b = "Please help ASAP.")
  httptest2::with_mock_dir("mocks", {
    out <- system_one_df(df, state = paste(a, b), !!!quickstart)
  })
  expect_s3_class(out, "tbl_df")
  expect_equal(out$tone, "angry")
})

test_that("each row sends one request with every question", {
  local_ts_env()
  bodies <- character()
  httr2::local_mocked_responses(function(req) {
    bodies <<- c(bodies, req$body$data)
    json_response(body = ok_body(list(
      billing = list(type = "noul", noul = 0.5),
      tone = list(type = "choice", choice = "calm", probabilities = list(calm = 1, angry = 0), confidence = 1)
    )))
  })
  df <- tibble::tibble(rec = list(list(subject = "A", n = 1L), list(subject = "B", n = 2L)))
  system_one_df(df, rec, billing = quickstart$billing, tone = quickstart$tone)

  expect_length(bodies, 2)
  parsed <- lapply(bodies, jsonlite::fromJSON, simplifyVector = FALSE)
  states <- lapply(parsed, `[[`, "state")
  expect_setequal(states, list(list(subject = "A", n = 1L), list(subject = "B", n = 2L)))
  for (p in parsed) {
    expect_named(p$questions, c("billing", "tone"))
    expect_equal(p$model, "jev-latest")
  }
})

test_that("on_error = 'stop' raises the first failed row's classed error", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) {
    state <- jsonlite::fromJSON(req$body$data)$state
    if (state == "bad") {
      json_response(422, list(detail = list(list(loc = list("body", "state"), msg = "too long", type = "x"))))
    } else {
      json_response(body = ok_body())
    }
  })
  df <- data.frame(s = c("ok", "bad", "ok"))
  err <- expect_error(system_one_df(df, s, q = ts_noul("?")), class = "typesafer_error_validation")
  expect_equal(err$row, 2)
  expect_snapshot(system_one_df(df, s, q = ts_noul("?")), error = TRUE)
})

test_that("on_error = 'continue' fills NA and records errors", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) {
    state <- jsonlite::fromJSON(req$body$data)$state
    if (state == "bad") {
      json_response(401, list(detail = "nope"))
    } else {
      json_response(body = ok_body(list(
        q = list(type = "noul", noul = 0.5),
        c = list(type = "choice", choice = "x", probabilities = list(x = 1, y = 0), confidence = 0.9)
      )))
    }
  })
  df <- data.frame(s = c("ok", "bad", "ok"))
  expect_snapshot(
    out <- system_one_df(
      df, s,
      q = ts_noul("?"), c = ts_choice("?", c("x", "y")),
      probs = TRUE, on_error = "continue"
    )
  )
  expect_equal(out$q, c(0.5, NA, 0.5))
  expect_equal(out$c, c("x", NA, "x"))
  expect_equal(out$c_confidence, c(0.9, NA, 0.9))
  expect_null(out$c_probs[[2]])
  expect_null(out$.error[[1]])
  expect_s3_class(out$.error[[2]], "typesafer_error_auth")
})

test_that("zero-row input returns typed empty columns without requests", {
  withr::local_envvar(TYPESAFE_API_KEY = NA)
  out <- system_one_df(tickets[0, ], text, !!!quickstart, probs = TRUE)
  expect_equal(nrow(out), 0)
  expect_type(out$billing, "double")
  expect_type(out$tone, "character")
  expect_type(out$tone_probs, "list")
})

test_that("arguments are validated", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) stop("should not be called"))
  expect_error(system_one_df(list(a = 1), a, q = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, q = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, text), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, id, q = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, c("a", "b"), q = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, text, q = ts_noul("?"), probs = NA), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, text, q = ts_noul("?"), max_active = 0), class = "typesafer_error_input")
  expect_error(system_one_df(tickets, text, q = ts_noul("?"), on_error = "skip"))
  df <- data.frame(s = c("a", NA))
  expect_snapshot(system_one_df(df, s, q = ts_noul("?")), error = TRUE)
})

test_that("output columns can't clash with existing columns", {
  local_ts_env()
  expect_snapshot(
    system_one_df(tickets, text, id = ts_noul("?"), tone = ts_choice("?", c("a", "b"))),
    error = TRUE
  )
  df <- tibble::tibble(text = "x", tone_confidence = 1)
  expect_error(
    system_one_df(df, text, tone = ts_choice("?", c("a", "b"))),
    class = "typesafer_error_input"
  )
})
