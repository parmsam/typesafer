#' Answer and response types
#'
#' @description
#' [system_one()] returns a `ts_response` holding one answer per question:
#'
#' * `ts_answer_noul`: `@prob`, the probability (0 to 1) that the answer is
#'   yes. Nouls have no separate confidence.
#' * `ts_answer_choice`: `@choice`, the highest-probability option;
#'   `@probabilities`, a named double vector with one probability per option;
#'   and `@confidence`.
#' * `ts_answer_score`: `@score`, the probability-weighted level, on the API's
#'   0-based scale (with levels `c("low", "medium", "high")`, `1.8` is close to
#'   `"high"`); `@probabilities`, a double vector ordered by level, so element
#'   `i` is the probability of level `i - 1`; `@legend`, the level descriptions
#'   in the same order; and `@confidence`.
#'
#' Confidence runs from 0 to 1 and summarizes how concentrated the probability
#' distribution is. See <https://docs.typesafe.ai/confidence>.
#'
#' A `ts_response` also keeps the parsed response body in `@json`, so you can
#' reach fields typesafer doesn't model yet (including answers of question
#' types it doesn't recognize). Its structure follows the API and may change.
#'
#' @param answers A named list of answers.
#' @param model The model that answered, e.g. `"jev-1.13.0"`.
#' @param usage A named integer vector with `input_tokens` and
#'   `output_tokens`.
#' @param json The parsed response body, as a list.
#' @param prob,choice,probabilities,score,legend,confidence Answer fields;
#'   see Description.
#' @returns An S7 object.
#' @examples
#' ts_response(
#'   answers = list(
#'     is_urgent = ts_answer_noul(prob = 0.95),
#'     department = ts_answer_choice(
#'       choice = "billing",
#'       probabilities = c(billing = 0.88, technical = 0.12, sales = 0),
#'       confidence = 0.81
#'     )
#'   ),
#'   model = "jev-1.13.0",
#'   usage = c(input_tokens = 318L, output_tokens = 34L)
#' )
#' @name ts_response
NULL

ts_answer <- S7::new_class("ts_answer", package = "typesafer", abstract = TRUE)

prop_prob <- function() {
  S7::new_property(
    S7::class_double,
    validator = function(value) {
      if (length(value) != 1 || (!is.na(value) && (value < 0 || value > 1))) {
        "must be a single number between 0 and 1"
      }
    }
  )
}

#' @rdname ts_response
#' @export
ts_answer_noul <- S7::new_class(
  "ts_answer_noul",
  parent = ts_answer,
  package = "typesafer",
  properties = list(prob = prop_prob())
)

#' @rdname ts_response
#' @export
ts_answer_choice <- S7::new_class(
  "ts_answer_choice",
  parent = ts_answer,
  package = "typesafer",
  properties = list(
    choice = S7::class_character,
    probabilities = S7::class_double,
    confidence = prop_prob()
  ),
  validator = function(self) {
    if (length(self@choice) != 1) {
      "@choice must be a single string."
    } else if (length(self@probabilities) > 0 && !rlang::is_named(self@probabilities)) {
      "@probabilities must be named by option."
    }
  }
)

#' @rdname ts_response
#' @export
ts_answer_score <- S7::new_class(
  "ts_answer_score",
  parent = ts_answer,
  package = "typesafer",
  properties = list(
    score = S7::class_double,
    probabilities = S7::class_double,
    legend = S7::class_list,
    confidence = prop_prob()
  ),
  validator = function(self) {
    if (length(self@score) != 1) {
      "@score must be a single number."
    } else if (length(self@legend) != length(self@probabilities)) {
      "@legend and @probabilities must have one element per level."
    }
  }
)

#' @rdname ts_response
#' @export
ts_response <- S7::new_class(
  "ts_response",
  package = "typesafer",
  properties = list(
    answers = S7::class_list,
    model = S7::class_character,
    usage = S7::class_integer,
    json = S7::class_list
  ),
  validator = function(self) {
    if (length(self@answers) > 0 && !rlang::is_named(self@answers)) {
      return("@answers must be a named list.")
    }
    ok <- vapply(self@answers, S7::S7_inherits, logical(1), class = ts_answer)
    if (!all(ok)) {
      return("@answers must only contain answer objects.")
    }
    if (length(self@model) != 1) {
      return("@model must be a single string.")
    }
    if (!setequal(names(self@usage), c("input_tokens", "output_tokens"))) {
      return("@usage must be named `input_tokens` and `output_tokens`.")
    }
    NULL
  }
)

# Parsing ---------------------------------------------------------------------

# `order` is the question names: answers come back in the API's order, so put
# them in the order the questions were asked (unexpected extras go last).
parse_response <- function(body, order = NULL, call = rlang::caller_env()) {
  answers <- body$answers %||% list()
  if (!is.null(order)) {
    answers <- answers[c(intersect(order, names(answers)), setdiff(names(answers), order))]
  }
  parsed <- lapply(answers, parse_answer)
  unknown <- vapply(parsed, is.null, logical(1))
  if (any(unknown)) {
    cli::cli_warn(
      c(
        "Ignoring answer{?s} with unrecognized type: {.val {names(answers)[unknown]}}.",
        i = "The raw answer is still available in the response's {.field @json}."
      ),
      call = call
    )
  }
  usage <- body$usage %||% list()
  ts_response(
    answers = parsed[!unknown],
    model = as.character(body$model %||% NA_character_),
    usage = c(
      input_tokens = as.integer(usage$input_tokens %||% NA_integer_),
      output_tokens = as.integer(usage$output_tokens %||% NA_integer_)
    ),
    json = body
  )
}

num <- function(x) as.double(x %||% NA_real_)

parse_answer <- function(x) {
  switch(
    x$type %||% "",
    noul = ts_answer_noul(prob = num(x$noul)),
    choice = ts_answer_choice(
      choice = as.character(x$choice),
      probabilities = vapply(x$probabilities %||% list(), num, double(1)),
      confidence = num(x$confidence)
    ),
    score = {
      probs <- by_level(x$probabilities)
      legend <- by_level(x$legend)
      ts_answer_score(
        score = num(x$score),
        probabilities = vapply(probs, num, double(1), USE.NAMES = FALSE),
        legend = unname(legend),
        confidence = num(x$confidence)
      )
    },
    NULL
  )
}

# Score maps use string keys "0", "1", ...: order them numerically.
by_level <- function(x) {
  x <- x %||% list()
  x[order(as.integer(names(x)))]
}

# Printing --------------------------------------------------------------------

fmt_num <- function(x, digits = 2) formatC(x, format = "f", digits = digits)

answer_summary <- S7::new_generic("answer_summary", "x")

S7::method(answer_summary, ts_answer_noul) <- function(x) {
  c(type = "noul", value = fmt_num(x@prob), extra = "")
}

S7::method(answer_summary, ts_answer_choice) <- function(x) {
  c(
    type = "choice",
    value = encodeString(x@choice, quote = '"'),
    extra = paste0("confidence ", fmt_num(x@confidence))
  )
}

S7::method(answer_summary, ts_answer_score) <- function(x) {
  c(
    type = "score",
    value = paste0(fmt_num(x@score), " [0-", length(x@probabilities) - 1L, "]"),
    extra = paste0("confidence ", fmt_num(x@confidence))
  )
}

S7::method(print, ts_answer) <- function(x, ...) {
  s <- answer_summary(x)
  cat(paste0("<ts_answer_", s[["type"]], "> ", s[["value"]]))
  if (nzchar(s[["extra"]])) cat(paste0(" (", s[["extra"]], ")"))
  cat("\n")
  invisible(x)
}

S7::method(print, ts_response) <- function(x, ...) {
  usage <- x@usage
  cat(sprintf(
    "<ts_response> %s | %s input / %s output tokens\n",
    x@model, usage[["input_tokens"]], usage[["output_tokens"]]
  ))
  if (length(x@answers) > 0) {
    s <- vapply(x@answers, answer_summary, character(3))
    lines <- paste(
      format(names(x@answers)),
      format(s["type", ]),
      format(s["value", ]),
      ifelse(nzchar(s["extra", ]), paste0("(", s["extra", ], ")"), "")
    )
    cat(paste0("  ", sub("\\s+$", "", lines)), sep = "\n")
  }
  invisible(x)
}
