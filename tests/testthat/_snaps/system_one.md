# arguments are validated before any request

    Code
      system_one("x", a = ts_noul("?"), b = 1)
    Condition
      Error in `system_one()`:
      ! Every argument in `...` must be a question created with `ts_noul()`, `ts_choice()`, or `ts_score()`.
      x `b` is not.

