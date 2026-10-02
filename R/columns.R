# Shared by system_one_df() and as_tibble(<ts_response>) so both produce the
# same columns for the same questions.

question_type <- function(q) {
  if (S7::S7_inherits(q, ts_noul)) {
    "noul"
  } else if (S7::S7_inherits(q, ts_choice)) {
    "choice"
  } else {
    "score"
  }
}

answer_type <- function(a) {
  if (S7::S7_inherits(a, ts_answer_noul)) {
    "noul"
  } else if (S7::S7_inherits(a, ts_answer_choice)) {
    "choice"
  } else {
    "score"
  }
}

# `types` is a named character vector of question types.
output_col_names <- function(types, probs) {
  unlist(lapply(names(types), function(name) {
    if (types[[name]] == "noul") {
      name
    } else {
      c(name, paste0(name, "_confidence"), if (probs) paste0(name, "_probs"))
    }
  }))
}

# `results` is a list of ts_response objects (or NULL for failed rows).
answer_columns <- function(name, type, results, probs) {
  answers <- lapply(results, function(r) if (!is.null(r)) r@answers[[name]])
  field <- function(prop, ptype) {
    vapply(answers, function(a) if (is.null(a)) ptype[NA_integer_] else S7::prop(a, prop), ptype)
  }

  if (type == "noul") {
    return(rlang::set_names(list(field("prob", double(1))), name))
  }
  value <- if (type == "choice") field("choice", character(1)) else field("score", double(1))
  cols <- rlang::set_names(
    list(value, field("confidence", double(1))),
    c(name, paste0(name, "_confidence"))
  )
  if (probs) {
    cols[[paste0(name, "_probs")]] <- lapply(answers, function(a) if (!is.null(a)) a@probabilities)
  }
  cols
}

#' Convert a response to a tibble
#'
#' Turns a [ts_response] into a one-row tibble with the same answer columns
#' that [system_one_df()] adds, so single requests and data frames can be
#' handled the same way.
#'
#' @param x A [ts_response].
#' @param ... Unused.
#' @param probs If `TRUE`, also add a `<name>_probs` list-column for each
#'   choice and score answer.
#' @returns A one-row tibble.
#' @name as_tibble.ts_response
#' @examples
#' resp <- ts_response(
#'   answers = list(
#'     urgent = ts_answer_noul(prob = 0.95),
#'     team = ts_answer_choice(
#'       choice = "billing",
#'       probabilities = c(billing = 0.88, technical = 0.12),
#'       confidence = 0.81
#'     )
#'   ),
#'   model = "jev-1.13.0",
#'   usage = c(input_tokens = 318L, output_tokens = 34L)
#' )
#' as_tibble(resp)
#' as_tibble(resp, probs = TRUE)
NULL

tibble_as_tibble <- S7::new_external_generic("tibble", "as_tibble", "x")

S7::method(tibble_as_tibble, ts_response) <- function(x, ..., probs = FALSE) {
  if (!rlang::is_bool(probs)) {
    abort_input("{.arg probs} must be `TRUE` or `FALSE`.")
  }
  types <- vapply(x@answers, answer_type, character(1))
  cols <- list()
  for (name in names(types)) {
    cols <- c(cols, answer_columns(name, types[[name]], list(x), probs))
  }
  tibble::new_tibble(cols, nrow = 1L)
}
