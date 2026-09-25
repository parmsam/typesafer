#' Ask System One questions about every row of a data frame
#'
#' Sends one request per row, with every question batched into that request,
#' and performs the requests in parallel with [httr2::req_perform_parallel()].
#' Rate-limited and failed requests are retried as described in
#' [typesafer_error].
#'
#' @param .data A data frame.
#' @param state <[`data-masking`][rlang::args_data_masking]> An expression
#'   evaluated in `.data` giving the state for each row: usually a character
#'   column (`state = text`), an expression such as
#'   `paste(subject, body, sep = "\n\n")`, or a list-column holding one
#'   structured state (a list) per row.
#' @inheritParams system_one
#' @param probs If `TRUE`, also add a `<name>_probs` list-column for each
#'   choice and score question holding its full probability distribution.
#' @param max_active Maximum number of requests in flight at once.
#' @param on_error What to do when a row's request fails after retries:
#'   * `"stop"` (default): stop sending requests and raise the error for the
#'     first failed row (see [typesafer_error]); the condition has a `row`
#'     field.
#'   * `"continue"`: finish every row, fill the answers of failed rows with
#'     `NA`, add a `.error` list-column holding each row's error (or `NULL`),
#'     and warn with a count of failed rows.
#' @returns `.data` as a tibble, with columns added for each question `name`:
#'   * noul: `name` (probability of yes).
#'   * choice: `name` (the chosen option) and `name_confidence`, plus
#'     `name_probs` (named double vectors) when `probs = TRUE`.
#'   * score: `name` (0-based expected level) and `name_confidence`, plus
#'     `name_probs` (double vectors ordered by level) when `probs = TRUE`.
#' @seealso [system_one()] for a single request.
#' @export
#' @examples
#' \dontrun{
#' tickets <- tibble::tibble(
#'   id = 1:3,
#'   text = c(
#'     "I was charged twice. Please help ASAP.",
#'     "How do I export my data to CSV?",
#'     "Your app crashed and I lost an hour of work!!"
#'   )
#' )
#' system_one_df(
#'   tickets,
#'   state = text,
#'   billing = ts_noul("Is this about billing?"),
#'   tone = ts_choice("What is the tone?", c("calm", "angry")),
#'   urgency = ts_score("How urgent is this?", c("low", "medium", "high"))
#' )
#' }
system_one_df <- function(.data,
                          state,
                          ...,
                          model = "jev-latest",
                          probs = FALSE,
                          max_active = 10,
                          on_error = c("stop", "continue"),
                          api_key = ts_api_key()) {
  if (!is.data.frame(.data)) {
    abort_input("{.arg .data} must be a data frame, not {.obj_type_friendly {(.data)}}.")
  }
  state <- rlang::enquo(state)
  if (rlang::quo_is_missing(state)) {
    abort_input("{.arg state} is required.")
  }
  questions <- check_questions(rlang::list2(...))
  check_model(model)
  if (!rlang::is_bool(probs)) {
    abort_input("{.arg probs} must be `TRUE` or `FALSE`.")
  }
  if (!rlang::is_scalar_integerish(max_active) || is.na(max_active) || max_active < 1) {
    abort_input("{.arg max_active} must be a whole number of at least 1.")
  }
  on_error <- rlang::arg_match(on_error)

  out <- tibble::as_tibble(.data)
  n <- nrow(out)
  states <- normalize_states(rlang::eval_tidy(state, out), n)

  new_cols <- output_col_names(questions, probs)
  if (on_error == "continue") {
    new_cols <- c(new_cols, ".error")
  }
  clash <- intersect(new_cols, names(out))
  if (length(clash) > 0) {
    abort_input(c(
      "{cli::qty(length(clash))}Output column{?s} {.field {clash}} already exist{?s/} in {.arg .data}.",
      i = "Rename the questions or the existing columns."
    ))
  }

  results <- vector("list", n)
  errors <- vector("list", n)
  if (n > 0) {
    check_api_key(api_key)
    reqs <- lapply(states, function(s) {
      ts_req_body(ts_request("v1/systemone", api_key), system_one_body(s, questions, model))
    })
    resps <- httr2::req_perform_parallel(
      reqs,
      on_error = if (on_error == "stop") "return" else "continue",
      max_active = max_active
    )
    call <- rlang::current_env()
    for (i in seq_len(n)) {
      r <- resps[[i]]
      if (inherits(r, "httr2_response")) {
        results[[i]] <- parse_response(httr2::resp_body_json(r, simplifyVector = FALSE), call = call)
      } else if (inherits(r, "error")) {
        errors[[i]] <- as_typesafer_cnd(r, call = call)
      }
    }
  }

  failed <- which(!vapply(errors, is.null, logical(1)))
  if (on_error == "stop" && length(failed) > 0) {
    cnd <- errors[[failed[[1]]]]
    cnd$message <- paste0("Row ", failed[[1]], ": ", cnd$message)
    cnd$row <- failed[[1]]
    rlang::cnd_signal(cnd)
  }

  for (name in names(questions)) {
    cols <- answer_columns(name, questions[[name]], results, probs)
    for (col in names(cols)) {
      out[[col]] <- cols[[col]]
    }
  }

  if (on_error == "continue") {
    out$.error <- errors
    if (length(failed) > 0) {
      cli::cli_warn(c(
        "{length(failed)} of {n} request{?s} failed; their answers are {.code NA}.",
        i = "See the {.field .error} column for the errors."
      ))
    }
  }
  out
}

normalize_states <- function(states, n, call = rlang::caller_env()) {
  if (is.factor(states)) {
    states <- as.character(states)
  }
  if (is.character(states)) {
    if (length(states) == 1) {
      states <- rep(states, n)
    }
    if (length(states) != n) {
      abort_input("{.arg state} must have one value per row ({n}), not {length(states)}.", call = call)
    }
    missing <- which(is.na(states))
    if (length(missing) > 0) {
      abort_input("{.arg state} can't be {.code NA}; see {cli::qty(length(missing))}row{?s} {missing}.", call = call)
    }
    return(as.list(states))
  }
  if (is.list(states) && !is.data.frame(states)) {
    if (length(states) != n) {
      abort_input("{.arg state} must have one value per row ({n}), not {length(states)}.", call = call)
    }
    bad <- which(!vapply(states, function(s) is_json_content(s) && !identical(s, NA_character_), logical(1)))
    if (length(bad) > 0) {
      abort_input("Each {.arg state} must be a single string or a list; see {cli::qty(length(bad))}row{?s} {bad}.", call = call)
    }
    return(states)
  }
  abort_input(
    "{.arg state} must evaluate to a character vector or a list, not {.obj_type_friendly {states}}.",
    call = call
  )
}

output_col_names <- function(questions, probs) {
  unlist(lapply(names(questions), function(name) {
    q <- questions[[name]]
    if (S7::S7_inherits(q, ts_noul)) {
      name
    } else {
      c(name, paste0(name, "_confidence"), if (probs) paste0(name, "_probs"))
    }
  }))
}

answer_columns <- function(name, question, results, probs) {
  answers <- lapply(results, function(r) if (!is.null(r)) r@answers[[name]])
  field <- function(prop, type) {
    vapply(answers, function(a) if (is.null(a)) type[NA_integer_] else S7::prop(a, prop), type)
  }
  prob_list <- function() {
    lapply(answers, function(a) if (!is.null(a)) a@probabilities)
  }

  if (S7::S7_inherits(question, ts_noul)) {
    cols <- list(field("prob", double(1)))
    names(cols) <- name
    return(cols)
  }
  value <- if (S7::S7_inherits(question, ts_choice)) {
    field("choice", character(1))
  } else {
    field("score", double(1))
  }
  cols <- list(value, field("confidence", double(1)))
  names(cols) <- c(name, paste0(name, "_confidence"))
  if (probs) {
    cols[[paste0(name, "_probs")]] <- prob_list()
  }
  cols
}
