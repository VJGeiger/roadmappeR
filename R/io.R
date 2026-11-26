.milestone_cols <- c("id", "track", "level", "label", "date", "after",
                     "status", "comment")

#' Path to the example milestones file
#'
#' A small TRL / MRL / FRL example (sample data) that ships with the package.
#' Copy it to start your own roadmap.
#'
#' @return A file path.
#' @export
#' @examples
#' roadmap_example()
#' \dontrun{
#' file.copy(roadmap_example(), "milestones.csv")
#' }
roadmap_example <- function() {
  system.file("extdata", "milestones.csv", package = "rlroadmap",
              mustWork = TRUE)
}

#' Read and write milestones
#'
#' `read_milestones()` reads the CSV (see [milestones-format]) as a data frame
#' of character columns. A missing file gives an empty data frame.
#' `write_milestones()` always overwrites the file with the current state (no
#' history is kept); it writes to a temporary file first and then renames it.
#'
#' @param path Path to the CSV file.
#' @param milestones A data frame with the columns described in
#'   [milestones-format].
#'
#' @return `read_milestones()`: a data frame. `write_milestones()`: `path`,
#'   invisibly.
#' @seealso [validate_milestones()]
#' @export
#' @examples
#' ms <- read_milestones(roadmap_example())
#' head(ms[, c("id", "track", "after")])
read_milestones <- function(path) {
  if (!file.exists(path)) {
    return(data.frame(matrix(character(), 0, length(.milestone_cols),
                             dimnames = list(NULL, .milestone_cols)),
                      stringsAsFactors = FALSE))
  }
  df <- read.csv(path, stringsAsFactors = FALSE, colClasses = "character",
                 na.strings = character(0), encoding = "UTF-8")
  # older files had a separate lag_months column: fold it into `after`
  if ("lag_months" %in% names(df)) {
    for (i in which(nzchar(df$after) & !grepl(":", df$after, fixed = TRUE))) {
      lag <- suppressWarnings(as.numeric(df$lag_months[i]))
      df$after[i] <- paste0(df$after[i], ":", ifelse(is.na(lag), 0, lag))
    }
  }
  for (col in setdiff(.milestone_cols, names(df))) df[[col]] <- ""
  df <- df[, .milestone_cols, drop = FALSE]
  df$comment <- gsub("\r", "", df$comment, fixed = TRUE)  # Excel line breaks
  df
}

#' @rdname read_milestones
#' @export
write_milestones <- function(milestones, path) {
  df <- milestones[, .milestone_cols, drop = FALSE]
  tmp <- paste0(path, ".tmp")
  write.csv(df, tmp, row.names = FALSE, fileEncoding = "UTF-8")
  file.rename(tmp, path)
  invisible(path)
}
