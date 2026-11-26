#' Export a standalone HTML snapshot
#'
#' Writes the current status as one self-contained interactive HTML file
#' (hover for details, no editing, no R needed to open it). Requires pandoc,
#' which RStudio ships.
#'
#' @param csv Path to the milestones CSV, see [milestones-format].
#' @param html Path of the HTML file to write.
#'
#' @return `html`, invisibly.
#' @seealso [plot_roadmap()], [run_roadmap()]
#' @export
#' @examples
#' \dontrun{
#' export_snapshot(roadmap_example(), "roadmap_snapshot.html")
#' }
export_snapshot <- function(csv, html = "roadmap_snapshot.html") {
  df <- read_milestones(csv)
  v <- validate_milestones(df)
  if (!v$ok) stop(v$message, call. = FALSE)
  p <- plot_roadmap(resolve_milestones(df), editable = FALSE,
                    title = paste("Readiness roadmap - status",
                                  format(Sys.Date())))
  saveWidget(p, normalizePath(html, mustWork = FALSE),
             selfcontained = TRUE, title = "Readiness roadmap")
  invisible(html)
}
