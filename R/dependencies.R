#' Parse and format the `after` column
#'
#' `parse_dependencies()` turns `"TRL4:5;MRL3:2.5"` into a data frame with
#' columns `pred` (predecessor id) and `lag` (months). A bare id has lag 0.
#' `format_dependencies()` is the inverse. See [milestones-format].
#'
#' @param x A single string (the `after` value).
#' @param pred Character vector of predecessor ids.
#' @param lag Numeric vector of lags in months, same length as `pred`.
#'
#' @return `parse_dependencies()`: a data frame with columns `pred` and `lag`
#'   (zero rows if there are no dependencies). `format_dependencies()`: a
#'   string (`""` if there are none).
#' @export
#' @examples
#' parse_dependencies("TRL4:5;MRL3:2.5")
#' format_dependencies(c("TRL4", "MRL3"), c(5, 2.5))
parse_dependencies <- function(x) {
  x <- trimws(x)
  if (is.na(x) || !nzchar(x)) {
    return(data.frame(pred = character(), lag = numeric(),
                      stringsAsFactors = FALSE))
  }
  parts <- trimws(strsplit(x, "[;,]")[[1]])
  parts <- parts[nzchar(parts)]
  has_lag <- grepl(":", parts, fixed = TRUE)
  data.frame(
    pred = trimws(sub(":.*$", "", parts)),
    lag  = suppressWarnings(as.numeric(ifelse(has_lag,
                                              sub("^[^:]*:", "", parts), "0"))),
    stringsAsFactors = FALSE)
}

#' @rdname parse_dependencies
#' @export
format_dependencies <- function(pred, lag) {
  if (!length(pred)) return("")
  paste0(pred, ":", vapply(lag, function(v) format(v, trim = TRUE), ""),
         collapse = ";")
}

#' Check milestones for problems
#'
#' Checks for duplicate or malformed ids, unknown or self-referencing
#' predecessors, negative or non-numeric lags, missing dates on fixed-date
#' milestones, and circular dependencies.
#'
#' @param milestones A data frame as returned by [read_milestones()].
#'
#' @return A list with `ok` (`TRUE`/`FALSE`) and `message` (empty if `ok`).
#' @export
#' @examples
#' validate_milestones(read_milestones(roadmap_example()))
validate_milestones <- function(milestones) {
  df <- milestones
  fail <- function(m) list(ok = FALSE, message = m)
  if (nrow(df) == 0) return(list(ok = TRUE, message = ""))
  if (any(grepl("[:;,]", df$id))) {
    return(fail(paste("Ids may not contain : ; ,  ->",
                      df$id[grepl("[:;,]", df$id)][1])))
  }
  if (anyDuplicated(df$id)) {
    return(fail(paste("Duplicate id:", df$id[anyDuplicated(df$id)])))
  }
  deps <- lapply(df$after, parse_dependencies)
  for (i in seq_len(nrow(df))) {
    d <- deps[[i]]
    if (nrow(d)) {
      if (any(!(d$pred %in% df$id)))
        return(fail(paste0(df$id[i], ": unknown predecessor ",
                           d$pred[!(d$pred %in% df$id)][1])))
      if (any(d$pred == df$id[i]))
        return(fail(paste(df$id[i], "can't depend on itself")))
      if (any(is.na(d$lag) | d$lag < 0))
        return(fail(paste0(df$id[i], ": lags must be numbers >= 0")))
      if (anyDuplicated(d$pred))
        return(fail(paste0(df$id[i], ": predecessor listed twice")))
    } else if (is.na(suppressWarnings(as.Date(df$date[i])))) {
      return(fail(paste0(df$id[i], ": needs a predecessor or a valid date ",
                         "(YYYY-MM-DD)")))
    }
  }
  # cycle check (depth-first, 0 = new, 1 = on current path, 2 = done)
  state <- setNames(rep(0, nrow(df)), df$id)
  names(deps) <- df$id
  visit <- function(id) {
    if (state[[id]] == 2) return(NULL)
    if (state[[id]] == 1) return(id)
    state[[id]] <<- 1
    for (p in deps[[id]]$pred) {
      r <- visit(p)
      if (!is.null(r)) return(r)
    }
    state[[id]] <<- 2
    NULL
  }
  for (id in df$id) {
    r <- visit(id)
    if (!is.null(r)) return(fail(paste("Circular dependency involving", r)))
  }
  list(ok = TRUE, message = "")
}

#' Compute milestone dates from their dependencies
#'
#' Adds `when` (a `Date`) to the milestones. Fixed-date milestones use `date`;
#' the others use the **latest** of "predecessor date + lag" over all their
#' dependencies. The predecessor that decides is returned in `driver`
#' (`""` for fixed-date milestones).
#'
#' @param milestones A valid data frame, see [validate_milestones()].
#'
#' @return `milestones` with the extra columns `when` and `driver`.
#' @export
#' @examples
#' ms <- resolve_milestones(read_milestones(roadmap_example()))
#' ms[ms$id %in% c("TRL7", "FRL6"), c("id", "when", "driver")]
resolve_milestones <- function(milestones) {
  df <- milestones
  n <- nrow(df)
  df$when <- as.Date(rep(NA_character_, n))
  df$driver <- rep("", n)
  if (n == 0) return(df)
  deps <- lapply(df$after, parse_dependencies)
  for (pass in seq_len(n + 1)) {
    todo <- which(is.na(df$when))
    if (!length(todo)) break
    for (i in todo) {
      d <- deps[[i]]
      if (!nrow(d)) {
        df$when[i] <- as.Date(df$date[i])
        next
      }
      pw <- df$when[match(d$pred, df$id)]
      if (anyNA(pw)) next
      cand <- as.Date(rep(NA_character_, nrow(d)))
      for (j in seq_len(nrow(d))) cand[j] <- add_months(pw[j], d$lag[j])
      k <- which.max(cand)
      df$when[i] <- cand[k]
      df$driver[i] <- d$pred[k]
    }
  }
  df
}

#' Move one milestone to a new date
#'
#' This is what dragging a point does. For a milestone with dependencies the
#' lag of the longest one is rewritten, so the rule stays true; for a
#' fixed-date milestone `date` is rewritten. Everything that depends on the
#' milestone follows automatically when the result is resolved again. The
#' move is refused (the input is returned unchanged, with a message) if the
#' milestone would land before its driving predecessor or before another
#' dependency's date.
#'
#' @param milestones A valid data frame, see [validate_milestones()].
#' @param id Id of the milestone to move.
#' @param new_date The new date (`Date` or `"YYYY-MM-DD"`).
#'
#' @return A list with `df` (the possibly changed milestones) and `message`
#'   (empty if the move was accepted).
#' @export
#' @examples
#' ms <- read_milestones(roadmap_example())
#' res <- move_milestone(ms, "TRL7", "2029-11-30")
#' res$df$after[res$df$id == "TRL7"]
move_milestone <- function(milestones, id, new_date) {
  df <- milestones
  i <- match(id, df$id)
  if (is.na(i)) return(list(df = df, message = paste("Unknown id", id)))
  new_date <- as.Date(new_date)
  d <- parse_dependencies(df$after[i])
  if (!nrow(d)) {
    df$date[i] <- format(new_date)
    return(list(df = df, message = ""))
  }
  r <- resolve_milestones(df)
  pw <- r$when[match(d$pred, r$id)]
  cand <- as.Date(rep(NA_character_, nrow(d)))
  for (j in seq_len(nrow(d))) cand[j] <- add_months(pw[j], d$lag[j])
  k <- which.max(cand)
  if (nrow(d) > 1) {
    others <- cand[-k]
    if (new_date < max(others)) {
      o <- which(cand == max(others))[1]
      return(list(df = df, message = sprintf(
        "%s can't be earlier than %s + %s months (= %s).", id, d$pred[o],
        format(d$lag[o], trim = TRUE), format(cand[o]))))
    }
  }
  lag <- months_between(pw[k], new_date)
  if (lag < 0) {
    return(list(df = df, message = sprintf(
      "%s can't be earlier than its predecessor %s.", id, d$pred[k])))
  }
  d$lag[k] <- lag
  df$after[i] <- format_dependencies(d$pred, d$lag)
  list(df = df, message = "")
}
