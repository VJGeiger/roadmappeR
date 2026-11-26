#' Plot the roadmap
#'
#' Draws one lane per track with a point wherever a level is reached (hollow
#' = planned, filled = achieved), dependency arrows with their lag (the
#' longest dependency is the dark arrow), quarterly ticks on the time axis and
#' a dashed line for today. Hovering a point shows its date, dependencies and
#' comment (which may span several lines).
#'
#' @param milestones A data frame as returned by [read_milestones()] or
#'   [resolve_milestones()]. Dates are resolved automatically if needed.
#' @param editable If `TRUE`, points can be dragged sideways and each drop is
#'   sent to 'shiny' as `input$dragged`. Only useful inside the app, see
#'   [run_roadmap()].
#' @param title Optional plot title.
#'
#' @return A plotly htmlwidget.
#' @seealso [export_snapshot()], [run_roadmap()]
#' @export
#' @examples
#' plot_roadmap(read_milestones(roadmap_example()))
plot_roadmap <- function(milestones, editable = FALSE, title = NULL) {
  df <- milestones
  if (nrow(df) == 0) {
    return(plot_ly() |> layout(title = "No milestones yet"))
  }
  if (!"when" %in% names(df)) df <- resolve_milestones(df)

  tracks <- unique(df$track)
  ypos <- setNames(rev(seq_along(tracks)), tracks)   # first track on top
  cols <- track_colors(tracks)
  df$y <- ypos[df$track]
  df$text <- ifelse(nzchar(df$label), df$label, paste(df$track, df$level))
  df$whenc <- format(df$when)
  esc <- htmlEscape
  deps <- lapply(df$after, parse_dependencies)

  hover <- vapply(seq_len(nrow(df)), function(i) {
    d <- deps[[i]]
    dep <- if (nrow(d)) {
      paste0(vapply(seq_len(nrow(d)), function(j) {
        sprintf("<br>%s months after %s%s", format(d$lag[j], trim = TRUE),
                esc(d$pred[j]),
                if (nrow(d) > 1 && d$pred[j] == df$driver[i]) " (longest)" else "")
      }, ""), collapse = "")
    } else "<br>fixed date"
    sprintf("<b>%s</b> (%s)<br>%s%s%s", esc(df$text[i]), esc(df$status[i]),
            df$whenc[i], dep, comment_html(df$comment[i]))
  }, character(1))

  # dependency arrows (annotations) + lag labels; the longest one is emphasised
  ann <- list()
  for (i in seq_len(nrow(df))) {
    d <- deps[[i]]
    for (j in seq_len(nrow(d))) {
      p <- match(d$pred[j], df$id)
      main <- nrow(d) == 1 || d$pred[j] == df$driver[i]
      ann[[length(ann) + 1]] <- list(
        x = df$whenc[i], y = df$y[i], ax = df$whenc[p], ay = df$y[p],
        xref = "x", yref = "y", axref = "x", ayref = "y", text = "",
        showarrow = TRUE, arrowhead = 2, arrowsize = 1,
        arrowwidth = if (main) 1.6 else 1,
        arrowcolor = if (main) "rgba(50,50,50,0.8)" else "rgba(130,130,130,0.45)",
        standoff = 8, startstandoff = 8)
      mid <- as.Date(df$whenc[p]) +
        (as.Date(df$whenc[i]) - as.Date(df$whenc[p])) / 2
      ann[[length(ann) + 1]] <- list(
        x = format(mid), y = (df$y[i] + df$y[p]) / 2, xref = "x", yref = "y",
        text = paste0("+", format(d$lag[j], trim = TRUE), " mo"),
        showarrow = FALSE, bgcolor = "#fafafa", borderpad = 1,
        font = list(size = 10, color = if (main) "#333" else "#888"))
    }
  }

  # connect consecutive levels within a track with a thin dotted line.
  # Shapes (not traces), so they can never steal hover from the markers.
  line_shapes <- list()
  for (tr in tracks) {
    d <- df[df$track == tr, ]
    d <- d[order(d$when), ]
    for (k in seq_len(nrow(d) - 1)) {
      line_shapes[[length(line_shapes) + 1]] <- list(
        type = "line", layer = "below", xref = "x", yref = "y",
        x0 = format(d$when[k]), x1 = format(d$when[k + 1]),
        y0 = d$y[k], y1 = d$y[k + 1],
        line = list(color = cols[[tr]], width = 2, dash = "dot"))
    }
  }

  achieved <- df$status == "achieved"
  p <- plot_ly(
    x = df$when, y = df$y, type = "scatter", mode = "markers+text",
    text = df$text, textposition = "top center", textfont = list(size = 12),
    hovertext = hover, hoverinfo = "text", showlegend = FALSE,
    marker = list(size = 16, symbol = "circle",
                  color = ifelse(achieved, cols[df$track], "white"),
                  line = list(color = cols[df$track], width = 3)))

  today <- Sys.Date()
  rng <- range(df$when)
  x_lo <- rng[1] - 90
  x_hi <- rng[2] + 90
  qt <- quarter_ticks(c(x_lo, x_hi))
  p <- layout(
    p, title = title, dragmode = FALSE, hovermode = "closest",
    xaxis = list(title = "", type = "date", showgrid = TRUE,
                 gridcolor = "#ebebeb", range = c(format(x_lo), format(x_hi)),
                 tickmode = "array", tickvals = qt$vals, ticktext = qt$text,
                 tickfont = list(size = 9, color = "#666"), ticklen = 3),
    yaxis = list(title = "", tickmode = "array", tickvals = unname(ypos),
                 ticktext = names(ypos), range = c(0.4, length(tracks) + 0.6),
                 fixedrange = TRUE, zeroline = FALSE, showgrid = FALSE),
    annotations = ann,
    shapes = c(line_shapes, list(list(
      type = "line", x0 = format(today), x1 = format(today),
      y0 = 0, y1 = 1, yref = "paper",
      line = list(color = "#999", width = 1, dash = "dash")))),
    margin = list(l = 70, r = 30, t = if (is.null(title)) 30 else 60, b = 50),
    plot_bgcolor = "#fafafa")
  p <- config(p, displaylogo = FALSE, scrollZoom = FALSE,
              modeBarButtonsToRemove = c("select2d", "lasso2d", "autoScale2d"))
  if (editable) {
    p <- onRender(p, drag_js(), data = list(markerTrace = 0, ids = df$id))
  }
  p
}

# --------------------------------------------------------------- helpers ----

# The JavaScript that makes the markers draggable (inst/js/drag.js).
#' @noRd
drag_js <- function() {
  path <- system.file("js", "drag.js", package = utils::packageName(), mustWork = TRUE)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' @noRd
track_colors <- function(tracks) {
  pal <- c("#2a6f97", "#c1666b", "#6a994e", "#e09f3e", "#7b5ea7", "#3d405b",
           "#2ec4b6", "#b5838d")
  setNames(rep_len(pal, length(tracks)), tracks)
}

# Quarter-start ticks covering a date range; year printed on Q1 and first tick.
#' @noRd
quarter_ticks <- function(rng) {
  a <- as.POSIXlt(rng[1])
  b <- as.POSIXlt(rng[2])
  q <- (a$year * 4 + a$mon %/% 3):(b$year * 4 + b$mon %/% 3)
  yr <- q %/% 4 + 1900
  qq <- q %% 4 + 1
  show_year <- qq == 1 | seq_along(q) == 1
  list(vals = format(as.Date(sprintf("%04d-%02d-01", yr, (qq - 1) * 3 + 1))),
       text = ifelse(show_year, sprintf("Q%d<br><b>%d</b>", qq, yr),
                     sprintf("Q%d", qq)))
}

# HTML for a (possibly multi-line) comment in a hover label.
#' @noRd
comment_html <- function(s) {
  s <- gsub("\r", "", s, fixed = TRUE)
  if (!nzchar(trimws(s))) return("")
  lines <- strsplit(s, "\n", fixed = TRUE)[[1]]
  wrapped <- unlist(lapply(lines, function(l)
    if (nzchar(trimws(l))) strwrap(l, 50) else ""))
  paste0("<br><i>", paste(htmlEscape(wrapped), collapse = "<br>"), "</i>")
}
