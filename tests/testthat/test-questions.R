wire_json <- function(q) as.character(ts_json(as_wire(q)))

# noul ------------------------------------------------------------------------

test_that("ts_noul() serializes without criteria", {
  q <- ts_noul("Does this convey urgency?")
  expect_true(S7::S7_inherits(q, ts_question))
  expect_null(q@criteria)
  expect_equal(
    wire_json(q),
    '{"type":"noul","instructions":"Does this convey urgency?"}'
  )
})

test_that("ts_noul() criteria keys are the strings true/false", {
  q <- ts_noul(
    "Does this convey urgency?",
    c(true = "Explicitly time-sensitive", false = "No urgency expressed")
  )
  expect_equal(
    wire_json(q),
    paste0(
      '{"type":"noul","instructions":"Does this convey urgency?",',
      '"criteria":{"true":"Explicitly time-sensitive","false":"No urgency expressed"}}'
    )
  )
  expect_equal(
    wire_json(ts_noul("x", list(false = "no"))),
    '{"type":"noul","instructions":"x","criteria":{"false":"no"}}'
  )
})

test_that("ts_noul() rejects bad criteria", {
  expect_error(ts_noul("x", c(yes = "a")), class = "typesafer_error_input")
  expect_error(ts_noul("x", c("a", "b")), class = "typesafer_error_input")
  expect_error(ts_noul("x", list(true = "a", true = "b")), class = "typesafer_error_input")
  expect_error(ts_noul("x", list(true = 1)), class = "typesafer_error_input")
})

test_that("instructions must be a string or list", {
  expect_error(ts_noul(1), class = "typesafer_error_input")
  expect_error(ts_noul(c("a", "b")), class = "typesafer_error_input")
  expect_error(ts_noul(), class = "typesafer_error_input")
  expect_snapshot(ts_noul(TRUE), error = TRUE)
})

test_that("structured instructions serialize as JSON objects and arrays", {
  q <- ts_noul(list(
    potential_duplicate = list(name = "John Smith", location = "Oakland, California"),
    question = "Is the resume for the same person as `potential_duplicate`?"
  ))
  round_trip <- jsonlite::fromJSON(wire_json(q), simplifyVector = FALSE)
  expect_equal(round_trip$instructions, q@instructions)

  expect_equal(
    wire_json(ts_noul(list("a", "b"))),
    '{"type":"noul","instructions":["a","b"]}'
  )
})

# choice ----------------------------------------------------------------------

test_that("bare character vector becomes options with null descriptions", {
  q <- ts_choice("What is the tone?", c("calm", "angry"))
  expect_equal(names(q@criteria), c("calm", "angry"))
  expect_equal(q@criteria, list(calm = NULL, angry = NULL))
  expect_equal(
    wire_json(q),
    '{"type":"choice","instructions":"What is the tone?","criteria":{"calm":null,"angry":null}}'
  )
})

test_that("named vector and list criteria map options to descriptions", {
  q <- ts_choice(
    "Which team should handle this?",
    c(
      billing = "Payments, invoicing, refunds",
      technical = "Bugs, outages, integrations",
      sales = "Pricing, upgrades, new accounts"
    )
  )
  expect_equal(
    jsonlite::fromJSON(wire_json(q), simplifyVector = FALSE)$criteria,
    list(
      billing = "Payments, invoicing, refunds",
      technical = "Bugs, outages, integrations",
      sales = "Pricing, upgrades, new accounts"
    )
  )

  mixed <- ts_choice("x", c(a = "desc", "b", c = NA))
  expect_equal(wire_json(mixed), '{"type":"choice","instructions":"x","criteria":{"a":"desc","b":null,"c":null}}')

  structured <- ts_choice("x", list(a = NULL, b = list(examples = list("x", "y"))))
  expect_equal(
    wire_json(structured),
    '{"type":"choice","instructions":"x","criteria":{"a":null,"b":{"examples":["x","y"]}}}'
  )
})

test_that("choice null descriptions never serialize as {}", {
  q <- ts_choice("x", list(only = NULL))
  expect_false(grepl("{}", wire_json(q), fixed = TRUE))
  expect_match(wire_json(q), '"only":null', fixed = TRUE)
})

test_that("choice allows up to 255 options", {
  expect_length(ts_choice("x", paste0("o", 1:255))@criteria, 255)
  expect_error(ts_choice("x", paste0("o", 1:256)), class = "typesafer_error_input")
  expect_snapshot(ts_choice("x", paste0("o", 1:256)), error = TRUE)
})

test_that("choice rejects empty, duplicate, and malformed options", {
  expect_error(ts_choice("x", character()), class = "typesafer_error_input")
  expect_error(ts_choice("x", c("a", "a")), class = "typesafer_error_input")
  expect_error(ts_choice("x", c(a = "1", "a")), class = "typesafer_error_input")
  expect_error(ts_choice("x", c("a", NA)), class = "typesafer_error_input")
  expect_error(ts_choice("x", list(1)), class = "typesafer_error_input")
  expect_error(ts_choice("x", list(a = 1)), class = "typesafer_error_input")
  expect_error(ts_choice("x", 1:3), class = "typesafer_error_input")
  expect_error(ts_choice("x"), class = "typesafer_error_input")
})

# score -----------------------------------------------------------------------

test_that("score criteria always serialize as a JSON array", {
  q <- ts_score("How frustrated is the customer?", c("Calm", "Frustrated", "Very angry"))
  expect_equal(
    wire_json(q),
    '{"type":"score","instructions":"How frustrated is the customer?","criteria":["Calm","Frustrated","Very angry"]}'
  )
  # Names are dropped rather than turning the array into an object.
  named <- ts_score("x", c(lo = "low", hi = "high"))
  expect_equal(wire_json(named), '{"type":"score","instructions":"x","criteria":["low","high"]}')

  structured <- ts_score("x", list(list(label = "low"), "high"))
  expect_equal(
    wire_json(structured),
    '{"type":"score","instructions":"x","criteria":[{"label":"low"},"high"]}'
  )
})

test_that("score requires 2 to 10 levels", {
  expect_length(ts_score("x", letters[1:2])@criteria, 2)
  expect_length(ts_score("x", letters[1:10])@criteria, 10)
  expect_error(ts_score("x", "a"), class = "typesafer_error_input")
  expect_error(ts_score("x", letters[1:11]), class = "typesafer_error_input")
  expect_error(ts_score("x", c("a", NA)), class = "typesafer_error_input")
  expect_error(ts_score("x", list("a", NULL)), class = "typesafer_error_input")
  expect_snapshot(ts_score("x", "a"), error = TRUE)
})

# S7 validators ---------------------------------------------------------------

test_that("validators run when properties are modified", {
  q <- ts_score("x", c("a", "b"))
  expect_error(q@criteria <- list("a"), "between 2 and 10")
  c <- ts_choice("x", c("a", "b"))
  expect_error(c@criteria <- list(), "at least one option")
  n <- ts_noul("x")
  expect_error(n@instructions <- 1, "single string or a list")
})

test_that("questions print", {
  expect_snapshot({
    ts_noul("Does this convey urgency?", c(true = "Yes", false = "No"))
    ts_choice("Which team?", c(billing = "Payments", "sales"))
    ts_score("How urgent?", c("low", "medium", "high"))
  })
})
