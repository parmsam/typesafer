test_that("noul answers parse", {
  resp <- parse_response(list(
    model = "jev-1.13.0",
    answers = list(is_urgent = list(type = "noul", noul = 0.95)),
    usage = list(input_tokens = 296, output_tokens = 20)
  ))
  expect_true(S7::S7_inherits(resp, ts_response))
  expect_equal(resp@model, "jev-1.13.0")
  expect_equal(resp@usage, c(input_tokens = 296L, output_tokens = 20L))
  expect_true(S7::S7_inherits(resp@answers$is_urgent, ts_answer_noul))
  expect_equal(resp@answers$is_urgent@prob, 0.95)
})

test_that("choice answers keep option names on probabilities", {
  a <- parse_answer(list(
    type = "choice",
    choice = "billing",
    probabilities = list(billing = 0.88, technical = 0.12, sales = 0),
    confidence = 0.81
  ))
  expect_equal(a@choice, "billing")
  expect_equal(a@probabilities, c(billing = 0.88, technical = 0.12, sales = 0))
  expect_equal(a@confidence, 0.81)
})

test_that("score string level keys become level-ordered vectors", {
  # Keys deliberately out of order, including a two-digit level.
  probs <- list("10" = 0.5, "0" = 0, "2" = 0.05, "1" = 0.45)
  probs[as.character(3:9)] <- 0
  legend <- stats::setNames(as.list(paste0("level ", c(10, 0, 2, 1, 3:9))), names(probs))

  a <- parse_answer(list(
    type = "score",
    score = 5.5,
    legend = legend,
    probabilities = probs,
    confidence = 0.4
  ))
  expect_equal(a@probabilities, c(0, 0.45, 0.05, rep(0, 7), 0.5))
  expect_null(names(a@probabilities))
  expect_equal(a@legend, as.list(paste0("level ", 0:10)))
  expect_equal(a@score, 5.5)
})

test_that("structured score legends are kept", {
  a <- parse_answer(list(
    type = "score",
    score = 0.2,
    legend = list("0" = list(label = "low"), "1" = "high"),
    probabilities = list("0" = 0.8, "1" = 0.2),
    confidence = 0.6
  ))
  expect_equal(a@legend, list(list(label = "low"), "high"))
})

test_that("unknown answer types are dropped with a warning", {
  expect_snapshot(
    resp <- parse_response(list(
      model = "jev-2",
      answers = list(
        a = list(type = "noul", noul = 0.1),
        b = list(type = "ranking", ranking = list("x"))
      ),
      usage = list(input_tokens = 1, output_tokens = 1)
    ))
  )
  expect_named(resp@answers, "a")
  expect_equal(resp@json$answers$b, list(type = "ranking", ranking = list("x")))
})

test_that("the parsed body is kept in @json", {
  body <- list(
    model = "jev-1.13.0",
    answers = list(q = list(type = "noul", noul = 0.5, extra = "new field")),
    usage = list(input_tokens = 1, output_tokens = 1),
    future_top_level = TRUE
  )
  resp <- parse_response(body)
  expect_identical(resp@json, body)
  expect_equal(resp@json$answers$q$extra, "new field")
  expect_equal(ts_response(model = "m", usage = c(input_tokens = 1L, output_tokens = 1L))@json, list())
})

test_that("answer validators reject impossible values", {
  expect_error(ts_answer_noul(prob = 1.5), "between 0 and 1")
  expect_error(ts_answer_choice(choice = c("a", "b"), probabilities = c(a = 1), confidence = 1), "single string")
  expect_error(
    ts_answer_score(score = 1, probabilities = c(0.5, 0.5), legend = list("a"), confidence = 1),
    "one element per level"
  )
  expect_error(ts_response(answers = list(1), model = "m", usage = c(input_tokens = 1L, output_tokens = 1L)))
})

test_that("responses and answers print", {
  resp <- parse_response(list(
    model = "jev-1.13.0",
    answers = list(
      is_urgent = list(type = "noul", noul = 0.95),
      department = list(
        type = "choice", choice = "billing",
        probabilities = list(billing = 0.88, technical = 0.12, sales = 0),
        confidence = 0.81
      ),
      frustration = list(
        type = "score", score = 1.05,
        legend = list("0" = "Calm", "1" = "Frustrated", "2" = "Very angry"),
        probabilities = list("0" = 0, "1" = 0.95, "2" = 0.05),
        confidence = 0.92
      )
    ),
    usage = list(input_tokens = 304, output_tokens = 18)
  ))
  expect_snapshot({
    resp
    resp@answers$is_urgent
    resp@answers$department
    resp@answers$frustration
  })
})
