# on_error = 'stop' raises the first failed row's classed error

    Code
      system_one_df(df, s, q = ts_noul("?"))
    Condition
      Error in `system_one_df()`:
      ! Row 2: TypeSafe API rejected the request as invalid (HTTP 422).
      x state: too long

# on_error = 'continue' fills NA and records errors

    Code
      out <- system_one_df(df, s, q = ts_noul("?"), c = ts_choice("?", c("x", "y")),
      probs = TRUE, on_error = "continue")
    Condition
      Warning:
      1 of 3 requests failed; their answers are `NA`.
      i See the .error column for the errors.

# arguments are validated

    Code
      system_one_df(df, s, q = ts_noul("?"))
    Condition
      Error in `system_one_df()`:
      ! `state` can't be `NA`; see row 2.

# output columns can't clash with existing columns

    Code
      system_one_df(tickets, text, id = ts_noul("?"), tone = ts_choice("?", c("a",
        "b")))
    Condition
      Error in `system_one_df()`:
      ! Output column id already exists in `.data`.
      i Rename the questions or the existing columns.

