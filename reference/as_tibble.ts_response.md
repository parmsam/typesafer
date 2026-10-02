# Convert a response to a tibble

Turns a
[ts_response](https://parmsam.github.io/typesafer/reference/ts_response.md)
into a one-row tibble with the same answer columns that
[`system_one_df()`](https://parmsam.github.io/typesafer/reference/system_one_df.md)
adds, so single requests and data frames can be handled the same way.

## Arguments

- x:

  A
  [ts_response](https://parmsam.github.io/typesafer/reference/ts_response.md).

- ...:

  Unused.

- probs:

  If `TRUE`, also add a `<name>_probs` list-column for each choice and
  score answer.

- include_usage:

  If `TRUE`, also add `input_tokens` and `output_tokens` columns.

## Value

A one-row tibble.

## Examples

``` r
resp <- ts_response(
  answers = list(
    urgent = ts_answer_noul(prob = 0.95),
    team = ts_answer_choice(
      choice = "billing",
      probabilities = c(billing = 0.88, technical = 0.12),
      confidence = 0.81
    )
  ),
  model = "jev-1.13.0",
  usage = c(input_tokens = 318L, output_tokens = 34L)
)
as_tibble(resp)
#> # A tibble: 1 × 3
#>   urgent team    team_confidence
#>    <dbl> <chr>             <dbl>
#> 1   0.95 billing            0.81
as_tibble(resp, probs = TRUE, include_usage = TRUE)
#> # A tibble: 1 × 6
#>   urgent team    team_confidence team_probs input_tokens output_tokens
#>    <dbl> <chr>             <dbl> <list>            <int>         <int>
#> 1   0.95 billing            0.81 <dbl [2]>           318            34
```
