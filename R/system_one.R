#' Ask System One questions about a state
#'
#' Sends one request to `POST /v1/systemone`: the model reads `state` once and
#' answers every question against it.
#'
#' @param state The content to evaluate: a single string, or a list for
#'   structured data such as a record or chat log (a named list becomes a JSON
#'   object, an unnamed list a JSON array). See
#'   <https://docs.typesafe.ai/concepts/state>.
#' @param ... Named questions created with [ts_noul()], [ts_choice()], or
#'   [ts_score()]. The names identify the answers and aren't shown to the
#'   model. You can also splice a named list of questions with `!!!`.
#' @param model The model to use. `"jev-latest"` is TypeSafe's flagship model;
#'   pin a versioned ID such as `"jev-1.13.0"` to keep answers stable. See
#'   [ts_models()].
#' @param api_key API key; defaults to [ts_api_key()].
#' @returns A [ts_response]. Answers are in `@answers`, named like the
#'   questions; the model that answered is in `@model`, and token counts are
#'   in `@usage`.
#' @seealso [system_one_df()] to ask the same questions about every row of a
#'   data frame. [typesafer_error] for the errors this can raise.
#' @export
#' @examples
#' \dontrun{
#' resp <- system_one(
#'   "I was charged twice. Please help ASAP.",
#'   billing = ts_noul("Is this about billing?"),
#'   tone = ts_choice("What is the tone?", c("calm", "angry")),
#'   urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
#' )
#' resp
#' resp@answers$billing@prob
#' resp@answers$tone@choice
#' resp@answers$urgency@score
#' }
system_one <- function(state, ..., model = "jev-latest", api_key = ts_api_key()) {
  check_state(state)
  questions <- check_questions(rlang::list2(...))
  check_model(model)
  check_api_key(api_key)

  req <- ts_request("v1/systemone", api_key)
  req <- ts_req_body(req, system_one_body(state, questions, model))
  parse_response(ts_perform(req, api_key = api_key))
}

system_one_body <- function(state, questions, model) {
  list(
    state = state,
    model = model,
    questions = lapply(questions, as_wire)
  )
}

check_state <- function(state, call = rlang::caller_env()) {
  if (missing(state)) {
    abort_input("{.arg state} is required.", call = call)
  }
  if (!is_json_content(state) || (rlang::is_string(state) && is.na(state))) {
    abort_input(
      "{.arg state} must be a single string or a list, not {.obj_type_friendly {state}}.",
      call = call
    )
  }
}

check_model <- function(model, call = rlang::caller_env()) {
  if (!rlang::is_string(model) || is.na(model) || !nzchar(model)) {
    abort_input("{.arg model} must be a single non-empty string.", call = call)
  }
}

check_questions <- function(questions, call = rlang::caller_env()) {
  if (length(questions) == 0) {
    abort_input(
      c(
        "At least one question is required.",
        i = "Pass named questions in {.arg ...}, e.g. {.code urgent = ts_noul(\"Is this urgent?\")}."
      ),
      call = call
    )
  }
  nms <- names(questions) %||% rep("", length(questions))
  if (any(is.na(nms) | nms == "")) {
    abort_input("All questions in {.arg ...} must be named.", call = call)
  }
  if (anyDuplicated(nms)) {
    abort_input("Question names must be unique; {.val {unique(nms[duplicated(nms)])}} is duplicated.", call = call)
  }
  ok <- vapply(questions, S7::S7_inherits, logical(1), class = ts_question)
  if (!all(ok)) {
    abort_input(
      c(
        "Every argument in {.arg ...} must be a question created with {.fn ts_noul}, {.fn ts_choice}, or {.fn ts_score}.",
        x = "{.arg {nms[!ok]}} {cli::qty(sum(!ok))}{?is/are} not."
      ),
      call = call
    )
  }
  questions
}
