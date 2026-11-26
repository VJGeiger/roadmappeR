#' The milestones CSV format
#'
#' Milestones are stored in one plain CSV file with these columns (all read as
#' text):
#'
#' \describe{
#'   \item{`id`}{Unique id, e.g. `TRL4`. May not contain `:`, `;` or `,`.}
#'   \item{`track`}{The lane the milestone is drawn in, e.g. `TRL`, `MRL`,
#'     `FRL`. A new track is simply a new value; there is no limit.}
#'   \item{`level`}{The readiness level reached, e.g. `4`.}
#'   \item{`label`}{Text shown next to the point. If empty, `track` and `level`
#'     are used ("TRL 4").}
#'   \item{`date`}{Fixed date, `YYYY-MM-DD`. Only used when `after` is empty.}
#'   \item{`after`}{Dependencies, see below. Empty for a fixed-date milestone.}
#'   \item{`status`}{`planned` (hollow point) or `achieved` (filled point).}
#'   \item{`comment`}{Free text shown on hover. May span several lines.}
#' }
#'
#' @section Dependencies:
#' `after` holds `id:months` pairs separated by `;`. `"TRL4:5;MRL3:2.5"` means
#' "5 months after TRL4 **and** 2.5 months after MRL3". The **latest** of these
#' dates is used (the longest dependency decides). A bare id means lag 0.
#' Circular dependencies are rejected by [validate_milestones()].
#'
#' Older files with a separate `lag_months` column are converted when read.
#'
#' @name milestones-format
#' @aliases milestones-format
#' @seealso [read_milestones()], [roadmap_example()]
NULL
