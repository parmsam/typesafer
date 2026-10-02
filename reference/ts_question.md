# Question types

TypeSafe questions come in three types:

- `ts_noul()`: a yes/no question. The answer is the probability that the
  answer is yes.

- `ts_choice()`: pick one option from a set of up to 255. The answer is
  the chosen option, a probability for every option, and a confidence.

- `ts_score()`: rate against 2 to 10 ordered levels. The answer is the
  probability-weighted level (0-based, so it can land between levels), a
  probability for every level, and a confidence.

Pass questions to
[`system_one()`](https://parmsam.github.io/typesafer/reference/system_one.md)
or
[`system_one_df()`](https://parmsam.github.io/typesafer/reference/system_one_df.md)
as named arguments; the names identify the answers.

## Usage

``` r
ts_noul(instructions, criteria = NULL)

ts_choice(instructions, criteria)

ts_score(instructions, criteria)
```

## Arguments

- instructions:

  The question to ask. Either a single string, or a list for structured
  instructions (a named list becomes a JSON object, an unnamed list a
  JSON array). See <https://docs.typesafe.ai/primitives/advanced>.

- criteria:

  What the answers mean:

  - `ts_noul()`: optional descriptions of a yes and a no, as a named
    character vector or list with names `true` and/or `false`, e.g.
    `c(true = "Explicitly time-sensitive", false = "No urgency expressed")`.

  - `ts_choice()`: the options. Either a bare character vector of option
    names (`c("calm", "angry")`), or a named character vector or list
    mapping each option to its description. Unnamed elements, `NA`, and
    `NULL` descriptions are sent as options with no description
    (`null`).

  - `ts_score()`: the ordered levels, lowest first, as a character
    vector or a list of structured descriptions. Level `i` is reported
    as score `i - 1`.

## Value

An S7 object inheriting from `ts_question`.

## Examples

``` r
ts_noul("Does this convey urgency?")
#> <ts_noul> Does this convey urgency?
ts_noul(
  "Does this convey urgency?",
  c(true = "Explicitly time-sensitive", false = "No urgency expressed")
)
#> <ts_noul> Does this convey urgency?
#>   true:  Explicitly time-sensitive
#>   false: No urgency expressed

ts_choice("What is the tone?", c("calm", "angry"))
#> <ts_choice> What is the tone?
#>   calm:
#>   angry:
ts_choice(
  "Which team should handle this?",
  c(
    billing = "Payments, invoicing, refunds",
    technical = "Bugs, outages, integrations",
    sales = "Pricing, upgrades, new accounts"
  )
)
#> <ts_choice> Which team should handle this?
#>   billing:   Payments, invoicing, refunds
#>   technical: Bugs, outages, integrations
#>   sales:     Pricing, upgrades, new accounts

ts_score("How frustrated is the customer?", c("Calm", "Frustrated", "Very angry"))
#> <ts_score> How frustrated is the customer?
#>   0: Calm
#>   1: Frustrated
#>   2: Very angry

# Structured instructions
ts_noul(list(
  potential_duplicate = list(name = "John Smith", location = "Oakland"),
  question = "Is the resume for the same person as `potential_duplicate`?"
))
#> <ts_noul> {"potential_duplicate":{"name":"John Smith","location":"O...
```
