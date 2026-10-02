# Errors

Every error raised by typesafer inherits from `typesafer_error`, so you
can catch them all with `tryCatch(..., typesafer_error = ...)`. More
specific classes:

- `typesafer_error_input`: invalid arguments, detected before any
  request is sent.

- `typesafer_error_auth`: the API key is missing, or the API rejected it
  (HTTP 401).

- `typesafer_error_http`: any unsuccessful HTTP response. Has fields
  `status`, `response_body` (parsed JSON, text, or `NULL`),
  `request_id`, and `resp` (the
  [`httr2::response()`](https://httr2.r-lib.org/reference/response.html)).
  Subclasses:

  - `typesafer_error_auth`: HTTP 401.

  - `typesafer_error_validation`: HTTP 422. The `details` field is a
    tibble with one row per offending field (`field`, `message`,
    `type`).

  - `typesafer_error_rate_limit`: HTTP 429 (rate limited) or 529
    (overloaded), after retries are exhausted.

  - `typesafer_error_server`: other 5xx responses, after retries are
    exhausted.

- `typesafer_error_connection`: the request never got a response (DNS,
  connection, or timeout failure), after retries are exhausted.

Requests that fail with 408, 429, or 5xx, or with a connection failure,
are retried with exponential backoff (0.5s doubling to at most 5s, with
jitter), within a 30 second budget. By default a request is tried up to
3 times; change that with the `max_tries` argument. `retry-after-ms` and
`retry-after` response headers are honored.

## Examples

``` r
tryCatch(
  ts_score("How urgent?", "high"),
  typesafer_error_input = function(e) conditionMessage(e)
)
#> [1] "\033[1m\033[22m`criteria` must have between 2 and 10 levels, not 1."
```
