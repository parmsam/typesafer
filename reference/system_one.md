# Ask System One questions about a state

Sends one request to `POST /v1/systemone`: the model reads `state` once
and answers every question against it.

## Usage

``` r
system_one(state, ..., model = "jev-latest", api_key = ts_api_key())
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

  The model to use. `"jev-latest"` is TypeSafe's flagship model; pin a
  versioned ID such as `"jev-1.13.0"` to keep answers stable. See
  [`ts_models()`](https://parmsam.github.io/typesafer/reference/ts_models.md).

- api_key:

  API key; defaults to
  [`ts_api_key()`](https://parmsam.github.io/typesafer/reference/ts_api_key.md).

## Value

A
[ts_response](https://parmsam.github.io/typesafer/reference/ts_response.md).
Answers are in `@answers`, named like the questions; the model that
answered is in `@model`, and token counts are in `@usage`.

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
