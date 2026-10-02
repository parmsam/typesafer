# Answer and response types

[`system_one()`](https://parmsam.github.io/typesafer/reference/system_one.md)
returns a `ts_response` holding one answer per question:

- `ts_answer_noul`: `@prob`, the probability (0 to 1) that the answer is
  yes. Nouls have no separate confidence.

- `ts_answer_choice`: `@choice`, the highest-probability option;
  `@probabilities`, a named double vector with one probability per
  option; and `@confidence`.

- `ts_answer_score`: `@score`, the probability-weighted level, on the
  API's 0-based scale (with levels `c("low", "medium", "high")`, `1.8`
  is close to `"high"`); `@probabilities`, a double vector ordered by
  level, so element `i` is the probability of level `i - 1`; `@legend`,
  the level descriptions in the same order; and `@confidence`.

Confidence runs from 0 to 1 and summarizes how concentrated the
probability distribution is. See <https://docs.typesafe.ai/confidence>.

A `ts_response` also keeps the parsed response body in `@json`, so you
can reach fields typesafer doesn't model yet (including answers of
question types it doesn't recognize). Its structure follows the API and
may change.

## Usage

``` r
ts_answer_noul(prob = numeric(0))

ts_answer_choice(
  choice = character(0),
  probabilities = numeric(0),
  confidence = numeric(0)
)

ts_answer_score(
  score = numeric(0),
  probabilities = numeric(0),
  legend = list(),
  confidence = numeric(0)
)

ts_response(
  answers = list(),
  model = character(0),
  usage = integer(0),
  json = list()
)
```

## Arguments

- prob, choice, probabilities, score, legend, confidence:

  Answer fields; see Description.

- answers:

  A named list of answers.

- model:

  The model that answered, e.g. `"jev-1.13.0"`.

- usage:

  A named integer vector with `input_tokens` and `output_tokens`.

- json:

  The parsed response body, as a list.

## Value

An S7 object.

## Examples

``` r
ts_response(
  answers = list(
    is_urgent = ts_answer_noul(prob = 0.95),
    department = ts_answer_choice(
      choice = "billing",
      probabilities = c(billing = 0.88, technical = 0.12, sales = 0),
      confidence = 0.81
    )
  ),
  model = "jev-1.13.0",
  usage = c(input_tokens = 318L, output_tokens = 34L)
)
#> <ts_response> jev-1.13.0 | 318 input / 34 output tokens
#>   is_urgent  noul   0.95
#>   department choice "billing" (confidence 0.81)
```
