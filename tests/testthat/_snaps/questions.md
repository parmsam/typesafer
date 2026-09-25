# instructions must be a string or list

    Code
      ts_noul(TRUE)
    Condition
      Error in `ts_noul()`:
      ! `instructions` must be a single string or a list, not `TRUE`.

# choice allows up to 255 options

    Code
      ts_choice("x", paste0("o", 1:256))
    Condition
      Error in `ts_choice()`:
      ! `criteria` can have at most 255 options, not 256.

# score requires 2 to 10 levels

    Code
      ts_score("x", "a")
    Condition
      Error in `ts_score()`:
      ! `criteria` must have between 2 and 10 levels, not 1.

# questions print

    Code
      ts_noul("Does this convey urgency?", c(true = "Yes", false = "No"))
    Output
      <ts_noul> Does this convey urgency?
        true:  Yes
        false: No
    Code
      ts_choice("Which team?", c(billing = "Payments", "sales"))
    Output
      <ts_choice> Which team?
        billing: Payments
        sales:
    Code
      ts_score("How urgent?", c("low", "medium", "high"))
    Output
      <ts_score> How urgent?
        0: low
        1: medium
        2: high

