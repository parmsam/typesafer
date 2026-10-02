# Ask System One questions about a state

Sends one request to `POST /v1/systemone`: the model reads `state` once
and answers every question against it.

## Usage

``` r
system_one(
  state,
  ...,
  model = ts_default_model(),
  max_tries = 3,
  timeout = ts_timeout(),
  api_key = ts_api_key()
)
```

## Arguments

- state:

  The content to evaluate: a single string, or a list for structured
  data such as a record or chat log (a named list becomes a JSON object,
  an unnamed list a JSON array). See
  <https://docs.typesafe.ai/concepts/state>.

- ...:

  Named questions created with
  [`ts_noul()`](https://parmsam.github.io/typesafer/reference/ts_question.md),
  [`ts_choice()`](https://parmsam.github.io/typesafer/reference/ts_question.md),
  or
  [`ts_score()`](https://parmsam.github.io/typesafer/reference/ts_question.md).
  The names identify the answers and aren't shown to the model. You can
  also splice a named list of questions with `!!!`.

- model:

  The model to use. Defaults to
  [`ts_default_model()`](https://parmsam.github.io/typesafer/reference/ts_default_model.md),
  which is `"jev-latest"`, TypeSafe's flagship model, unless the
  `TYPESAFE_DEFAULT_MODEL` environment variable says otherwise. Pin a
  versioned ID such as `"jev-1.13.0"` to keep answers stable. See
  [`ts_models()`](https://parmsam.github.io/typesafer/reference/ts_models.md).

- max_tries:

  Maximum number of attempts per request, including the first. Requests
  that fail with 408, 429, 5xx, or a connection failure are retried with
  exponential backoff, within a 30 second retry budget. Use `1` to
  disable retries.

- timeout:

  Timeout for each attempt, in seconds. Defaults to the
  `typesafer.timeout` option, or 10.

- api_key:

  API key; defaults to
  [`ts_api_key()`](https://parmsam.github.io/typesafer/reference/ts_api_key.md).

## Value

A
[ts_response](https://parmsam.github.io/typesafer/reference/ts_response.md).
Answers are in `@answers`, named like the questions; the model that
answered is in `@model`, and token counts are in `@usage`. Use
[as_tibble()](https://parmsam.github.io/typesafer/reference/as_tibble.ts_response.md)
to get the answers as a one-row tibble.

## See also

[`system_one_df()`](https://parmsam.github.io/typesafer/reference/system_one_df.md)
to ask the same questions about every row of a data frame.
[typesafer_error](https://parmsam.github.io/typesafer/reference/typesafer_error.md)
for the errors this can raise.

## Examples

``` r
if (FALSE) { # \dontrun{
resp <- system_one(
  "I was charged twice. Please help ASAP.",
  billing = ts_noul("Is this about billing?"),
  tone = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)
resp
resp@answers$billing@prob
resp@answers$tone@choice
resp@answers$urgency@score
} # }
```
