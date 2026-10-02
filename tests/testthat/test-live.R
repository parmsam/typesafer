# Integration tests against the live TypeSafe API. See skip_if_no_live_api()
# in helper.R: they run locally when TYPESAFE_API_KEY is set, and are skipped on
# CRAN and CI. Answers are model output, so assertions check structure and
# only clear-cut semantics.

expect_prob <- function(x) {
  expect_type(x, "double")
  expect_length(x, 1)
  expect_true(x >= 0 && x <= 1)
}

test_that("live: system_one() answers all three question types", {
  skip_if_no_live_api()

  resp <- system_one(
    "I was charged twice. Please help ASAP.",
    billing = ts_noul("Is this about billing?"),
    tone = ts_choice("What is the tone?", c("calm", "angry")),
    urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
  )

  expect_true(S7::S7_inherits(resp, ts_response))
  expect_match(resp@model, "^jev-")
  expect_named(resp@answers, c("billing", "tone", "urgency"), ignore.order = TRUE)
  expect_true(all(resp@usage > 0))

  billing <- resp@answers$billing
  expect_true(S7::S7_inherits(billing, ts_answer_noul))
  expect_prob(billing@prob)
  expect_gt(billing@prob, 0.5)

  tone <- resp@answers$tone
  expect_true(S7::S7_inherits(tone, ts_answer_choice))
  expect_true(tone@choice %in% c("calm", "angry"))
  expect_setequal(names(tone@probabilities), c("calm", "angry"))
  expect_equal(sum(tone@probabilities), 1, tolerance = 1e-3)
  expect_equal(tone@choice, names(which.max(tone@probabilities)))
  expect_prob(tone@confidence)

  urgency <- resp@answers$urgency
  expect_true(S7::S7_inherits(urgency, ts_answer_score))
  expect_true(urgency@score >= 0 && urgency@score <= 2)
  expect_length(urgency@probabilities, 3)
  expect_equal(sum(urgency@probabilities), 1, tolerance = 1e-3)
  expect_equal(urgency@legend, list("low", "medium", "high"))
  expect_equal(urgency@score, sum(0:2 * urgency@probabilities), tolerance = 0.05)
  expect_prob(urgency@confidence)
})

test_that("live: structured state, instructions, and criteria are accepted", {
  skip_if_no_live_api()

  resp <- system_one(
    list(subject = "Duplicate charge", message = "I was billed twice this month."),
    dept = ts_choice(
      list(question = "Which team should handle `subject`?", note = "Pick one team."),
      c(billing = "Payments, invoicing, refunds", technical = NA)
    ),
    urgent = ts_noul(
      "Does this convey urgency?",
      c(true = "Explicitly time-sensitive", false = "No urgency expressed")
    ),
    severity = ts_score("How severe is the problem?", list(list(label = "minor"), list(label = "major")))
  )

  expect_equal(resp@answers$dept@choice, "billing")
  expect_prob(resp@answers$urgent@prob)
  expect_equal(resp@answers$severity@legend, list(list(label = "minor"), list(label = "major")))
})

test_that("live: system_one_df() keeps row order across parallel requests", {
  skip_if_no_live_api()

  tickets <- tibble::tibble(
    id = 1:2,
    text = c(
      "How do I export my data to CSV?",
      "Your app crashed and I lost an hour of work!!"
    )
  )
  out <- system_one_df(
    tickets,
    state = text,
    tone = ts_choice("What is the tone?", c("calm", "angry")),
    urgency = ts_score("How urgent is this?", c("low", "medium", "high")),
    probs = TRUE
  )

  expect_equal(out$id, 1:2)
  expect_equal(out$tone, c("calm", "angry"))
  expect_lt(out$urgency[[1]], out$urgency[[2]])
  expect_setequal(names(out$tone_probs[[1]]), c("calm", "angry"))
  expect_length(out$urgency_probs[[2]], 3)
})

test_that("live: ts_models() lists jev-latest", {
  skip_if_no_live_api()

  models <- ts_models()
  expect_true("jev-latest" %in% models$name)
  expect_s3_class(models$release_date, "Date")
  expect_false(anyNA(models$release_date))
})

test_that("live: an invalid key raises typesafer_error_auth", {
  skip_if_no_live_api()

  err <- expect_error(
    system_one("x", q = ts_noul("?"), api_key = "not-a-real-key"),
    class = "typesafer_error_auth"
  )
  expect_equal(err$status, 401L)
  expect_type(err$request_id, "character")
})

test_that("live: an unknown model raises typesafer_error_http (400)", {
  skip_if_no_live_api()

  err <- expect_error(
    system_one("x", q = ts_noul("?"), model = "no-such-model"),
    class = "typesafer_error_http"
  )
  expect_equal(err$status, 400L)
  expect_match(conditionMessage(err), "no-such-model")
})

test_that("live: server-side validation raises typesafer_error_validation", {
  skip_if_no_live_api()

  # The constructors reject these locally, so build the request by hand.
  req <- ts_req_body(
    ts_request("v1/systemone", ts_api_key()),
    list(
      state = "x",
      model = "jev-latest",
      questions = list(
        q = list(type = "score", instructions = "?", criteria = list()),
        t = list(type = "choice", instructions = "?")
      )
    )
  )
  err <- expect_error(ts_perform(req), class = "typesafer_error_validation")
  expect_equal(err$status, 422L)
  expect_setequal(err$details$field, c("questions.q.criteria", "questions.t.criteria"))
})
