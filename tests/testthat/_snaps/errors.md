# missing API key is a typesafer_error_auth

    Code
      ts_api_key()
    Condition
      Error in `ts_api_key()`:
      ! No TypeSafe API key found.
      i Set the `TYPESAFE_API_KEY` environment variable, e.g. in '~/.Renviron'.

# 401 is a typesafer_error_auth

    Code
      call_with_response(resp)
    Condition
      Error in `system_one()`:
      ! TypeSafe API rejected the API key (HTTP 401).
      x Invalid API key
      i Check the key in the `TYPESAFE_API_KEY` environment variable.
      i Request ID: req_123

# 422 is a typesafer_error_validation with field details

    Code
      call_with_response(resp)
    Condition
      Error in `system_one()`:
      ! TypeSafe API rejected the request as invalid (HTTP 422).
      x questions.tone.criteria: Field required
      x questions.urgency.criteria.0: Input should be a valid string

# 429 and 529 are typesafer_error_rate_limit after retries

    Code
      call_with_response(json_response(529, list(error = list(message = "Overloaded"))))
    Condition
      Error in `system_one()`:
      ! TypeSafe API is overloaded (HTTP 529).
      x Overloaded
      i Retries with backoff were exhausted; wait before trying again.

# other 4xx are plain typesafer_error_http

    Code
      call_with_response(httr2::response(404))
    Condition
      Error in `system_one()`:
      ! TypeSafe API request failed (HTTP 404 Not Found).

