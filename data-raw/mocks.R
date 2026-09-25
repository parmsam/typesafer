# Builds the httptest2 mock responses in tests/testthat/mocks/ from the
# request/response examples in the API reference
# (https://docs.typesafe.ai/api.md and https://docs.typesafe.ai/models.md).
#
# The mock file names hash the request body, so rerun this script whenever the
# request serialization changes on purpose:
#
#   Rscript data-raw/mocks.R

pkgload::load_all()

mock_dir <- file.path("tests", "testthat", "mocks")
unlink(mock_dir, recursive = TRUE)

state <- "Help! My payouts have been failing for 3 days."

write_mock <- function(req, body) {
  path <- file.path(mock_dir, paste0(httptest2::build_mock_url(req), ".json"))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(body, path)
  message("Wrote ", path)
}

systemone_mock <- function(questions, response, state = "Help! My payouts have been failing for 3 days.") {
  req <- ts_request("v1/systemone", "test-key")
  req <- ts_req_body(req, system_one_body(state, questions, "jev-latest"))
  write_mock(req, response)
}

# Noul, from the "Example request" / "Noul answer" examples.
systemone_mock(
  list(is_urgent = ts_noul("Does this convey urgency?")),
  '{
  "model": "jev-1.13.0",
  "answers": {
    "is_urgent": {
      "type": "noul",
      "noul": 0.95
    }
  },
  "usage": { "input_tokens": 296, "output_tokens": 20 }
}'
)

# Noul with criteria.
systemone_mock(
  list(is_urgent = ts_noul(
    "Does this convey urgency?",
    c(true = "Explicitly time-sensitive", false = "No urgency expressed")
  )),
  '{
  "model": "jev-1.13.0",
  "answers": {
    "is_urgent": {
      "type": "noul",
      "noul": 0.95
    }
  },
  "usage": { "input_tokens": 307, "output_tokens": 20 }
}'
)

# Choice.
systemone_mock(
  list(department = ts_choice(
    "Which team should handle this?",
    c(
      billing = "Payments, invoicing, refunds",
      technical = "Bugs, outages, integrations",
      sales = "Pricing, upgrades, new accounts"
    )
  )),
  '{
  "model": "jev-1.13.0",
  "answers": {
    "department": {
      "type": "choice",
      "choice": "billing",
      "probabilities": { "billing": 0.88, "technical": 0.12, "sales": 0.0 },
      "confidence": 0.81
    }
  },
  "usage": { "input_tokens": 318, "output_tokens": 34 }
}'
)

# Score.
systemone_mock(
  list(frustration = ts_score(
    "How frustrated is the customer?",
    c("Calm", "Frustrated", "Very angry")
  )),
  '{
  "model": "jev-1.13.0",
  "answers": {
    "frustration": {
      "type": "score",
      "score": 1.05,
      "legend": { "0": "Calm", "1": "Frustrated", "2": "Very angry" },
      "probabilities": { "0": 0.0, "1": 0.95, "2": 0.05 },
      "confidence": 0.92
    }
  },
  "usage": { "input_tokens": 304, "output_tokens": 18 }
}'
)

# All three types in one request (the SDK quickstart), with an answer type
# this client doesn't know about to check forward compatibility.
quickstart <- list(
  billing = ts_noul("Is this about billing?"),
  tone = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)
quickstart_response <- function(billing, tone, calm, urgency, p) {
  sprintf(
    '{
  "model": "jev-1.13.0",
  "answers": {
    "billing": { "type": "noul", "noul": %s },
    "tone": {
      "type": "choice",
      "choice": "%s",
      "probabilities": { "calm": %s, "angry": %s },
      "confidence": 0.7
    },
    "urgency": {
      "type": "score",
      "score": %s,
      "legend": { "0": "low", "1": "medium", "2": "high" },
      "probabilities": { "0": %s, "1": %s, "2": %s },
      "confidence": 0.8
    }
  },
  "usage": { "input_tokens": 350, "output_tokens": 45 }
}',
    billing, tone, calm, 1 - calm, urgency, p[1], p[2], p[3]
  )
}
tickets <- c(
  "I was charged twice. Please help ASAP.",
  "How do I export my data to CSV?",
  "Your app crashed and I lost an hour of work!!"
)
systemone_mock(quickstart, quickstart_response(0.97, "angry", 0.1, 1.8, c(0.05, 0.1, 0.85)), state = tickets[[1]])
systemone_mock(quickstart, quickstart_response(0.02, "calm", 0.95, 0.3, c(0.75, 0.2, 0.05)), state = tickets[[2]])
systemone_mock(quickstart, quickstart_response(0.05, "angry", 0.15, 1.6, c(0.1, 0.2, 0.7)), state = tickets[[3]])

systemone_mock(
  list(is_urgent = ts_noul("Does this convey urgency?")),
  '{
  "model": "jev-1.13.0",
  "answers": {
    "is_urgent": { "type": "noul", "noul": 0.95 },
    "future": { "type": "ranking", "ranking": ["a", "b"] }
  },
  "usage": { "input_tokens": 296, "output_tokens": 20 }
}',
  state = "Forward compatible?"
)

# Models, from https://docs.typesafe.ai/models.md and the OpenAPI example.
write_mock(
  ts_request("v1/models", "test-key"),
  '{
  "models": [
    {
      "name": "jev-latest",
      "description": "General-purpose system one model.",
      "release_date": "2026-09-15"
    },
    {
      "name": "jev-preview",
      "description": "The most recent release, whether or not it is an official one.",
      "release_date": "2026-09-15"
    }
  ]
}'
)
