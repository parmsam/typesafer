# Changelog

## typesafer 0.1.0

First release of typesafer, an unofficial R client for the [TypeSafe
System One API](https://docs.typesafe.ai/api).

### Questions

- [`ts_noul()`](https://parmsam.github.io/typesafer/reference/ts_question.md),
  [`ts_choice()`](https://parmsam.github.io/typesafer/reference/ts_question.md),
  and
  [`ts_score()`](https://parmsam.github.io/typesafer/reference/ts_question.md)
  create typed questions as S7 classes, validated before any request is
  sent.
  - Choice criteria accept a bare character vector of options or a named
    vector or list of descriptions. Options without a description are
    sent as JSON `null`. A choice can have at most 255 options.
  - Score criteria take 2 to 10 ordered levels and are always sent as a
    JSON array.
  - Noul criteria optionally describe what `true` and `false` mean.
  - Instructions, options, and levels accept strings or structured
    lists.

### Asking questions

- [`system_one()`](https://parmsam.github.io/typesafer/reference/system_one.md)
  asks any number of named questions about one state (a string or
  structured data) in a single request. It returns a `ts_response` with
  typed answers, the model that answered, and token usage.
- [`system_one_df()`](https://parmsam.github.io/typesafer/reference/system_one_df.md)
  asks the same questions about every row of a data frame, with one
  request per row, run in parallel with
  [`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html).
  It adds a probability column for each noul, a value and `_confidence`
  column for each choice and score, and optional `_probs` list-columns.
  `on_error = "continue"` keeps the rows that succeeded when others
  fail.
- Score answers stay on the API’s 0-based scale, with probabilities and
  level descriptions returned as vectors ordered by level.
- [`ts_models()`](https://parmsam.github.io/typesafer/reference/ts_models.md)
  lists the models available to your account.

### Reliability

- Requests are retried on 408, 429, 5xx, and connection failures with
  exponential backoff and jitter, honoring `retry-after-ms` and
  `retry-after`, matching the official Python SDK’s defaults.
- Errors are classed conditions inheriting from `typesafer_error`:
  - `typesafer_error_auth`
  - `typesafer_error_validation`, with a `details` tibble of the
    offending fields
  - `typesafer_error_rate_limit`
  - `typesafer_error_server`
  - `typesafer_error_http`
  - `typesafer_error_connection`
  - `typesafer_error_input`
- [`ts_api_key()`](https://parmsam.github.io/typesafer/reference/ts_api_key.md)
  reads `TYPESAFE_API_KEY` and gives a clear error when it’s missing. A
  rejected key’s error says whether it came from that variable or from
  the `api_key` argument.
