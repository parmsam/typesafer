#' Question types
#'
#' @description
#' TypeSafe questions come in three types:
#'
#' * `ts_noul()`: a yes/no question. The answer is the probability that the
#'   answer is yes.
#' * `ts_choice()`: pick one option from a set of up to 255. The answer is
#'   the chosen option, a probability for every option, and a confidence.
#' * `ts_score()`: rate against 2 to 10 ordered levels. The answer is the
#'   probability-weighted level (0-based, so it can land between levels), a
#'   probability for every level, and a confidence.
#'
#' Pass questions to [system_one()] or [system_one_df()] as named arguments;
#' the names identify the answers.
#'
#' @param instructions The question to ask. Either a single string, or a list
#'   for structured instructions (a named list becomes a JSON object, an
#'   unnamed list a JSON array). See
#'   <https://docs.typesafe.ai/primitives/advanced>.
#' @param criteria What the answers mean:
#'
#'   * `ts_noul()`: optional descriptions of a yes and a no, as a named
#'     character vector or list with names `true` and/or `false`, e.g.
#'     `c(true = "Explicitly time-sensitive", false = "No urgency expressed")`.
#'   * `ts_choice()`: the options. Either a bare character vector of option
#'     names (`c("calm", "angry")`), or a named character vector or list
#'     mapping each option to its description. Unnamed elements, `NA`, and
#'     `NULL` descriptions are sent as options with no description (`null`).
#'   * `ts_score()`: the ordered levels, lowest first, as a character vector
#'     or a list of structured descriptions. Level `i` is reported as score
#'     `i - 1`.
#'
#' @returns An S7 object inheriting from `ts_question`.
#' @examples
#' ts_noul("Does this convey urgency?")
#' ts_noul(
#'   "Does this convey urgency?",
#'   c(true = "Explicitly time-sensitive", false = "No urgency expressed")
#' )
#'
#' ts_choice("What is the tone?", c("calm", "angry"))
#' ts_choice(
#'   "Which team should handle this?",
#'   c(
#'     billing = "Payments, invoicing, refunds",
#'     technical = "Bugs, outages, integrations",
#'     sales = "Pricing, upgrades, new accounts"
#'   )
#' )
#'
#' ts_score("How frustrated is the customer?", c("Calm", "Frustrated", "Very angry"))
#'
#' # Structured instructions
#' ts_noul(list(
#'   potential_duplicate = list(name = "John Smith", location = "Oakland"),
#'   question = "Is the resume for the same person as `potential_duplicate`?"
#' ))
#' @name ts_question
NULL

ts_question <- S7::new_class(
  "ts_question",
  package = "typesafer",
  abstract = TRUE,
  properties = list(
    instructions = S7::class_any
  ),
  validator = function(self) {
    if (!is_json_content(self@instructions)) {
      "@instructions must be a single string or a list."
    }
  }
)

#' @rdname ts_question
#' @export
ts_noul <- S7::new_class(
  "ts_noul",
  parent = ts_question,
  package = "typesafer",
  properties = list(
    criteria = S7::class_any
  ),
  constructor = function(instructions, criteria = NULL) {
    check_instructions(instructions)
    criteria <- normalize_noul_criteria(criteria)
    S7::new_object(S7::S7_object(), instructions = instructions, criteria = criteria)
  },
  validator = function(self) {
    validate_noul_criteria(self@criteria)
  }
)

#' @rdname ts_question
#' @export
ts_choice <- S7::new_class(
  "ts_choice",
  parent = ts_question,
  package = "typesafer",
  properties = list(
    criteria = S7::class_list
  ),
  constructor = function(instructions, criteria) {
    check_instructions(instructions)
    criteria <- normalize_choice_criteria(criteria)
    S7::new_object(S7::S7_object(), instructions = instructions, criteria = criteria)
  },
  validator = function(self) {
    validate_choice_criteria(self@criteria)
  }
)

#' @rdname ts_question
#' @export
ts_score <- S7::new_class(
  "ts_score",
  parent = ts_question,
  package = "typesafer",
  properties = list(
    criteria = S7::class_list
  ),
  constructor = function(instructions, criteria) {
    check_instructions(instructions)
    criteria <- normalize_score_criteria(criteria)
    S7::new_object(S7::S7_object(), instructions = instructions, criteria = criteria)
  },
  validator = function(self) {
    validate_score_criteria(self@criteria)
  }
)

# Validation ----------------------------------------------------------------

check_instructions <- function(instructions, call = rlang::caller_env()) {
  if (missing(instructions)) {
    abort_input("{.arg instructions} is required.", call = call)
  }
  if (!is_json_content(instructions)) {
    abort_input(
      "{.arg instructions} must be a single string or a list, not {.obj_type_friendly {instructions}}.",
      call = call
    )
  }
}

check_criteria_values <- function(values, allow_null, call) {
  ok <- vapply(
    values,
    if (allow_null) is_json_content_or_null else is_json_content,
    logical(1)
  )
  if (!all(ok)) {
    bad <- names(values)[!ok] %||% which(!ok)
    abort_input(
      c(
        "Each description in {.arg criteria} must be a single string or a list.",
        x = "Problem with {.val {bad}}."
      ),
      call = call
    )
  }
}

validate_noul_criteria <- function(criteria) {
  if (is.null(criteria)) {
    return(NULL)
  }
  if (!is.list(criteria) || !rlang::is_named(criteria)) {
    return("@criteria must be NULL or a named list.")
  }
  if (!all(names(criteria) %in% c("true", "false")) || anyDuplicated(names(criteria))) {
    return("@criteria names must be `true` and/or `false`, each at most once.")
  }
  if (!all(vapply(criteria, is_json_content_or_null, logical(1)))) {
    return("@criteria descriptions must be single strings, lists, or NULL.")
  }
  NULL
}

validate_choice_criteria <- function(criteria) {
  n <- length(criteria)
  if (n == 0) {
    return("@criteria must have at least one option.")
  }
  if (n > 255) {
    return(sprintf("@criteria can have at most 255 options, not %d.", n))
  }
  nms <- names(criteria)
  if (is.null(nms) || any(is.na(nms) | nms == "")) {
    return("@criteria options must all be named.")
  }
  if (anyDuplicated(nms)) {
    return(sprintf("@criteria options must be unique; duplicated: %s.", nms[duplicated(nms)][[1]]))
  }
  if (!all(vapply(criteria, is_json_content_or_null, logical(1)))) {
    return("@criteria descriptions must be single strings, lists, or NULL.")
  }
  NULL
}

validate_score_criteria <- function(criteria) {
  n <- length(criteria)
  if (n < 2 || n > 10) {
    return(sprintf("@criteria must have between 2 and 10 levels, not %d.", n))
  }
  if (!all(vapply(criteria, is_json_content, logical(1)))) {
    return("@criteria levels must be single strings or lists.")
  }
  NULL
}

abort_if_invalid <- function(msg, call) {
  if (!is.null(msg)) {
    abort_input(sub("^@criteria", "{.arg criteria}", msg), call = call)
  }
}

# Normalization -------------------------------------------------------------

na_to_null <- function(x) {
  lapply(x, function(el) if (length(el) == 1 && is.atomic(el) && is.na(el)) NULL else el)
}

normalize_noul_criteria <- function(criteria, call = rlang::caller_env()) {
  if (is.null(criteria) || length(criteria) == 0) {
    return(NULL)
  }
  if (is.character(criteria)) {
    criteria <- as.list(criteria)
  }
  if (!is.list(criteria) || !rlang::is_named(criteria)) {
    abort_input(
      "{.arg criteria} must be a named character vector or list with names {.val true} and/or {.val false}.",
      call = call
    )
  }
  criteria <- na_to_null(criteria)
  check_criteria_values(criteria, allow_null = TRUE, call = call)
  abort_if_invalid(validate_noul_criteria(criteria), call)
  criteria
}

normalize_choice_criteria <- function(criteria, call = rlang::caller_env()) {
  if (missing(criteria)) {
    abort_input("{.arg criteria} is required.", call = call)
  }
  if (is.factor(criteria)) {
    criteria <- as.character(criteria)
  }
  if (is.character(criteria)) {
    if (anyNA(criteria) && is.null(names(criteria))) {
      abort_input("Option names in {.arg criteria} can't be {.val NA}.", call = call)
    }
    criteria <- as.list(criteria)
  }
  if (!is.list(criteria)) {
    abort_input(
      "{.arg criteria} must be a character vector or a list, not {.obj_type_friendly {criteria}}.",
      call = call
    )
  }

  nms <- names(criteria) %||% rep("", length(criteria))
  nms[is.na(nms)] <- ""
  unnamed <- nms == ""
  for (i in which(unnamed)) {
    el <- criteria[[i]]
    if (!rlang::is_string(el) || is.na(el) || el == "") {
      abort_input(
        "Unnamed elements of {.arg criteria} must be option names (non-empty strings); element {i} isn't.",
        call = call
      )
    }
    nms[[i]] <- el
  }

  out <- na_to_null(criteria)
  out[unnamed] <- list(NULL)
  names(out) <- nms
  check_criteria_values(out, allow_null = TRUE, call = call)
  abort_if_invalid(validate_choice_criteria(out), call)
  out
}

normalize_score_criteria <- function(criteria, call = rlang::caller_env()) {
  if (missing(criteria)) {
    abort_input("{.arg criteria} is required.", call = call)
  }
  if (is.character(criteria)) {
    if (anyNA(criteria)) {
      abort_input("Levels in {.arg criteria} can't be {.val NA}.", call = call)
    }
    criteria <- as.list(criteria)
  }
  if (!is.list(criteria)) {
    abort_input(
      "{.arg criteria} must be a character vector or a list, not {.obj_type_friendly {criteria}}.",
      call = call
    )
  }
  criteria <- unname(criteria)
  check_criteria_values(criteria, allow_null = FALSE, call = call)
  abort_if_invalid(validate_score_criteria(criteria), call)
  criteria
}

# Serialization --------------------------------------------------------------

# Returns the wire representation of a question as a list, ready for ts_json().
as_wire <- S7::new_generic("as_wire", "x")

S7::method(as_wire, ts_noul) <- function(x) {
  out <- list(type = "noul", instructions = x@instructions)
  if (!is.null(x@criteria)) {
    out$criteria <- x@criteria
  }
  out
}

S7::method(as_wire, ts_choice) <- function(x) {
  list(type = "choice", instructions = x@instructions, criteria = x@criteria)
}

S7::method(as_wire, ts_score) <- function(x) {
  # An unnamed list always serializes as a JSON array, even with one element.
  list(type = "score", instructions = x@instructions, criteria = unname(x@criteria))
}

# Printing -------------------------------------------------------------------

describe_json <- function(x, width = 60) {
  if (is.null(x)) {
    return("")
  }
  if (rlang::is_string(x)) {
    return(x)
  }
  s <- as.character(ts_json(x))
  if (nchar(s) > width) paste0(substr(s, 1, width - 3), "...") else s
}

S7::method(print, ts_question) <- function(x, ...) {
  cat("<", sub("^typesafer::", "", class(x)[[1]]), "> ", describe_json(x@instructions), "\n", sep = "")
  crit <- x@criteria
  if (length(crit) > 0) {
    labels <- if (S7::S7_inherits(x, ts_score)) {
      paste0(seq_along(crit) - 1L, ":")
    } else {
      paste0(names(crit), ":")
    }
    desc <- vapply(crit, describe_json, character(1))
    lines <- sprintf("  %s %s", format(labels), desc)
    cat(sub("\\s+$", "", lines), sep = "\n")
  }
  invisible(x)
}
