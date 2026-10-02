# List available models

Calls `GET /v1/models`, which lists the model names your account can
send in the `model` argument. It currently lists the aliases (such as
`"jev-latest"`); versioned IDs such as `"jev-1.13.0"` are accepted
whether or not they're listed. See <https://docs.typesafe.ai/models>.

## Usage

``` r
ts_models(max_tries = 3, timeout = ts_timeout(), api_key = ts_api_key())
```

## Arguments

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

A tibble with columns `name`, `description`, and `release_date` (a
Date).

## Examples

``` r
if (FALSE) { # \dontrun{
ts_models()
} # }
```
