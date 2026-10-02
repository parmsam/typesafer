test_that("noul example from the API reference", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(spec_state, is_urgent = ts_noul("Does this convey urgency?"))
  })
  expect_equal(resp@model, "jev-1.13.0")
  expect_equal(resp@usage[["input_tokens"]], 296L)
  expect_equal(resp@answers$is_urgent@prob, 0.95)
})

test_that("noul with criteria example", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(
      spec_state,
      is_urgent = ts_noul(
        "Does this convey urgency?",
        c(true = "Explicitly time-sensitive", false = "No urgency expressed")
      )
    )
  })
  expect_equal(resp@usage[["input_tokens"]], 307L)
})

test_that("choice example", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(
      spec_state,
      department = ts_choice(
        "Which team should handle this?",
        c(
          billing = "Payments, invoicing, refunds",
          technical = "Bugs, outages, integrations",
          sales = "Pricing, upgrades, new accounts"
        )
      )
    )
  })
  a <- resp@answers$department
  expect_equal(a@choice, "billing")
  expect_equal(a@probabilities, c(billing = 0.88, technical = 0.12, sales = 0))
  expect_equal(a@confidence, 0.81)
})

test_that("score example", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(
      spec_state,
      frustration = ts_score("How frustrated is the customer?", c("Calm", "Frustrated", "Very angry"))
    )
  })
  a <- resp@answers$frustration
  expect_equal(a@score, 1.05)
  expect_equal(a@probabilities, c(0, 0.95, 0.05))
  expect_equal(a@legend, list("Calm", "Frustrated", "Very angry"))
  expect_equal(a@confidence, 0.92)
})

test_that("questions can be spliced from a list", {
  local_ts_env()
  qs <- list(is_urgent = ts_noul("Does this convey urgency?"))
  httptest2::with_mock_dir("mocks", {
    resp <- system_one(spec_state, !!!qs)
  })
  expect_named(resp@answers, "is_urgent")
})

test_that("unknown answer types in a response are ignored", {
  local_ts_env()
  httptest2::with_mock_dir("mocks", {
    expect_warning(
      resp <- system_one("Forward compatible?", is_urgent = ts_noul("Does this convey urgency?")),
      "unrecognized type"
    )
  })
  expect_named(resp@answers, "is_urgent")
})

test_that("request body, URL, and headers match the API", {
  local_ts_env()
  seen <- NULL
  httr2::local_mocked_responses(function(req) {
    seen <<- req
    json_response(body = ok_body(list(
      billing = list(type = "noul", noul = 0.9),
      tone = list(type = "choice", choice = "calm", probabilities = list(calm = 1, angry = 0), confidence = 1),
      urgency = list(
        type = "score", score = 0, legend = list("0" = "low", "1" = "high"),
        probabilities = list("0" = 1, "1" = 0), confidence = 1
      )
    )))
  })
  system_one(
    list(subject = "Duplicate charge", message = "Please help."),
    billing = ts_noul("Is this about billing?"),
    tone = ts_choice("What is the tone?", c("calm", "angry")),
    urgency = ts_score("How urgent?", c("low", "high")),
    model = "jev-1.13.0"
  )

  expect_equal(seen$url, "https://api.typesafe.ai/v1/systemone")
  expect_equal(httr2::req_get_method(seen), "POST")
  headers <- httr2::req_get_headers(seen, redacted = "reveal")
  expect_equal(headers$Authorization, "Bearer test-key")
  expect_equal(headers$Accept, "application/json")
  expect_equal(seen$body$content_type, "application/json")
  expect_match(seen$options$useragent, "^typesafer/")

  expect_equal(
    seen$body$data,
    paste0(
      '{"state":{"subject":"Duplicate charge","message":"Please help."},',
      '"model":"jev-1.13.0",',
      '"questions":{',
      '"billing":{"type":"noul","instructions":"Is this about billing?"},',
      '"tone":{"type":"choice","instructions":"What is the tone?","criteria":{"calm":null,"angry":null}},',
      '"urgency":{"type":"score","instructions":"How urgent?","criteria":["low","high"]}',
      "}}"
    )
  )
})

test_that("TYPESAFE_BASE_URL overrides the host", {
  withr::local_envvar(TYPESAFE_API_KEY = "k", TYPESAFE_BASE_URL = "http://localhost:1234/")
  seen <- NULL
  httr2::local_mocked_responses(function(req) {
    seen <<- req
    json_response(body = ok_body())
  })
  system_one("x", q = ts_noul("?"))
  expect_equal(seen$url, "http://localhost:1234/v1/systemone")
})

test_that("arguments are validated before any request", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) stop("should not be called"))
  expect_error(system_one("x"), class = "typesafer_error_input")
  expect_error(system_one("x", ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one("x", a = ts_noul("?"), a = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one("x", a = "not a question"), class = "typesafer_error_input")
  expect_error(system_one(c("a", "b"), a = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one(NA_character_, a = ts_noul("?")), class = "typesafer_error_input")
  expect_error(system_one("x", a = ts_noul("?"), model = ""), class = "typesafer_error_input")
  expect_error(system_one(a = ts_noul("?")), class = "typesafer_error_input")
  expect_snapshot(system_one("x", a = ts_noul("?"), b = 1), error = TRUE)
})

test_that("answers follow question order, not the API's order", {
  local_ts_env()
  httr2::local_mocked_responses(function(req) {
    json_response(body = ok_body(list(
      c = list(type = "noul", noul = 0.3),
      a = list(type = "noul", noul = 0.1),
      b = list(type = "noul", noul = 0.2)
    )))
  })
  resp <- system_one("x", a = ts_noul("?"), b = ts_noul("?"), c = ts_noul("?"))
  expect_named(resp@answers, c("a", "b", "c"))
  expect_named(as_tibble(resp), c("a", "b", "c"))
  # The raw body keeps the API's order.
  expect_named(resp@json$answers, c("c", "a", "b"))
})
