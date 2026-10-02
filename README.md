# typesafer

<!-- badges: start -->
[![R-CMD-check](https://github.com/parmsam/typesafer/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/parmsam/typesafer/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

typesafer is an **unofficial** R client for the
[TypeSafe System One API](https://docs.typesafe.ai/api). You send a piece of
state (text or structured data) and a set of typed questions, and get back
calibrated probabilities your code can act on:

* `ts_noul()`: yes/no questions. The answer is the probability of yes.
* `ts_choice()`: pick one of up to 255 options. The answer is the chosen
  option, a probability for every option, and a confidence.
* `ts_score()`: rate against 2 to 10 ordered levels. The answer is the
  probability-weighted level, a probability for every level, and a
  confidence.

typesafer isn't affiliated with or endorsed by TypeSafe.

## Installation

Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("parmsam/typesafer")
```

## Authentication

Get an API key from TypeSafe and set it in the `TYPESAFE_API_KEY` environment
variable, for example by adding this line to your `.Renviron`
(`usethis::edit_r_environ()`):

```
TYPESAFE_API_KEY=your-key-here
```

## Quickstart

Ask several questions about one piece of state in a single request:

``` r
library(typesafer)

resp <- system_one(
  "I was charged twice. Please help ASAP.",
  billing = ts_noul("Is this about billing?"),
  tone    = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)

resp@answers$billing@prob
resp@answers$tone@choice
resp@answers$urgency@score
```

Printing the response gives a one-line summary per answer:

``` r
resp
#> <ts_response> jev-1.13.0 | 350 input / 45 output tokens
#>   billing noul   0.97
#>   tone    choice "angry"    (confidence 0.70)
#>   urgency score  1.80 [0-2] (confidence 0.80)
```

(Output is illustrative.) Scores use the API's 0-based scale: with levels
`c("low", "medium", "high")`, `1.8` is close to `"high"`.

Choice options can carry descriptions, and instructions, options, and levels
can all be structured lists:

``` r
ts_choice(
  "Which team should handle this?",
  c(
    billing   = "Payments, invoicing, refunds",
    technical = "Bugs, outages, integrations",
    sales     = "Pricing, upgrades, new accounts"
  )
)

ts_noul(
  "Does this convey urgency?",
  c(true = "Explicitly time-sensitive", false = "No urgency expressed")
)
```

## Data frames

`system_one_df()` sends one request per row, with every question batched into
that request, and runs the requests in parallel. It returns the input as a
tibble with answer columns added:

``` r
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
  tone    = ts_choice("What is the tone?", c("calm", "angry")),
  urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
)
#> # A tibble: 3 × 7
#>      id text               billing tone  tone_confidence urgency urgency_confidence
#>   <int> <chr>                <dbl> <chr>           <dbl>   <dbl>              <dbl>
#> 1     1 I was charged twi…    0.97 angry             0.7     1.8                0.8
#> 2     2 How do I export m…    0.02 calm              0.7     0.3                0.8
#> 3     3 Your app crashed …    0.05 angry             0.7     1.6                0.8
```

(Output is illustrative.) Set `probs = TRUE` to also get each choice and score
probability distribution as a list-column. Use `on_error = "continue"` to keep
the rows that succeeded when some requests fail. Failed rows get `NA` answers
and their errors go in an `.error` column.

## Errors and retries

Requests that are rate limited (429), hit an overloaded server (529) or another
5xx, time out (408), or fail to connect are retried twice with exponential
backoff. `retry-after` headers are respected. Errors are classed conditions
that inherit from `typesafer_error`:

| Class                         | When                                     |
| ----------------------------- | ---------------------------------------- |
| `typesafer_error_auth`        | Missing API key, or HTTP 401             |
| `typesafer_error_validation`  | HTTP 422; `err$details` lists the fields |
| `typesafer_error_rate_limit`  | HTTP 429 or 529 after retries            |
| `typesafer_error_server`      | Other HTTP 5xx after retries             |
| `typesafer_error_http`        | Any unsuccessful HTTP response           |
| `typesafer_error_connection`  | No response after retries                |
| `typesafer_error_input`       | Invalid arguments, before any request    |

``` r
tryCatch(
  system_one("Is this spam?", spam = ts_noul("Is this message spam?")),
  typesafer_error_validation = function(err) err$details,
  typesafer_error_rate_limit = function(err) NULL
)
```

## Models

`ts_models()` lists the models your account can use. `jev-latest` is the
default. Pin a versioned ID such as `jev-1.13.0` if you have tuned thresholds
against a specific release.

## Development

``` r
devtools::test()   # uses recorded mocks; no API key needed
devtools::check()
```

`tests/testthat/test-live.R` also runs a few tests against the live API when
`TYPESAFE_API_KEY` is set. They're skipped on CRAN and CI.

See [AGENTS.md](AGENTS.md) for the package layout, conventions, JSON
serialization gotchas, and how the test fixtures are generated.
