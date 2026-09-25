# unknown answer types are dropped with a warning

    Code
      resp <- parse_response(list(model = "jev-2", answers = list(a = list(type = "noul",
        noul = 0.1), b = list(type = "ranking", ranking = list("x"))), usage = list(
        input_tokens = 1, output_tokens = 1)))
    Condition
      Warning:
      Ignoring answer with unrecognized type: "b".

# responses and answers print

    Code
      resp
    Output
      <ts_response> jev-1.13.0 | 304 input / 18 output tokens
        is_urgent   noul   0.95
        department  choice "billing"  (confidence 0.81)
        frustration score  1.05 [0-2] (confidence 0.92)
    Code
      resp@answers$is_urgent
    Output
      <ts_answer_noul> 0.95
    Code
      resp@answers$department
    Output
      <ts_answer_choice> "billing" (confidence 0.81)
    Code
      resp@answers$frustration
    Output
      <ts_answer_score> 1.05 [0-2] (confidence 0.92)

