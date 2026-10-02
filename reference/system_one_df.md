# Ask System One questions about every row of a data frame

Sends one request per row, with every question batched into that
request, and performs the requests in parallel with
[`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html).
Rate-limited and failed requests are retried as described in
[typesafer_error](https://parmsam.github.io/typesafer/reference/typesafer_error.md).

## Usage

``` r
system_one_df(
  .data,
  state,
  ...,
  model = ts_default_model(),
  probs = FALSE,
  include_usage = FALSE,
  max_active = 10,
  on_error = c("stop", "continue"),
  max_tries = 3,
  timeout = ts_timeout(),
  api_key = ts_api_key()
)
```

## Arguments

- .data:

  A data frame.

- state:

  \<[`data-masking`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  An expression evaluated in `.data` giving the state for each row:
  usually a character column (`state = text`), an expression such as
  `paste(subject, body, sep = "\n\n")`, or a list-column holding one
  structured state (a list) per row.

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

- probs:

  If `TRUE`, also add a `<name>_probs` list-column for each choice and
  score question holding its full probability distribution.

- include_usage:

  If `TRUE`, also add `input_tokens` and `output_tokens` columns with
  each row's token usage (`NA` for failed rows).

- max_active:

  Maximum number of requests in flight at once.

- on_error:

  What to do when a row's request fails after retries:

  - `"stop"` (default): stop sending requests and raise the error for
    the first failed row (see
    [typesafer_error](https://parmsam.github.io/typesafer/reference/typesafer_error.md));
    the condition has a `row` field.

  - `"continue"`: finish every row, fill the answers of failed rows with
    `NA`, add a `.error` list-column holding each row's error (or
    `NULL`), and warn with a count of failed rows.

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

`.data` as a tibble, with columns added for each question `name`:

- noul: `name` (probability of yes).

- choice: `name` (the chosen option) and `name_confidence`, plus
  `name_probs` (named double vectors) when `probs = TRUE`.

- score: `name` (0-based expected level) and `name_confidence`, plus
  `name_probs` (double vectors ordered by level) when `probs = TRUE`.

Plus `input_tokens` and `output_tokens` when `include_usage = TRUE`, and
`.error` when `on_error = "continue"`.

## See also

[`system_one()`](https://parmsam.github.io/typesafer/reference/system_one.md)
for a single request.

## Examples

``` r
if (FALSE) { # \dontrun{
tickets <- tibble::tibble(
  id = 1:3,
  text = c(
    "I was charged twice. Please help ASAP.",
    "How do I export my data to CSV?",
    "Your app crashed and I lost an hour of work!!"
  )
)
system_one_df(
  tickets,
  state = text,
  billing = ts_noul("Is this about billing?"),
  tone = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)
} # }
```
