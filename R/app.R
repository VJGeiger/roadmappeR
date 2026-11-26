#' Run the interactive roadmap app
#'
#' Opens a 'shiny' app on a milestones CSV: **drag** a point sideways to move
#' it, **click** a point to edit its label, status, dependencies and comment,
#' and **add** milestones or whole new tracks. Every change is written straight
#' back to the CSV (latest state only). With several dependencies the longest
#' one decides the date and is drawn as the dark arrow; dragging rewrites its
#' lag and everything that depends on the milestone moves along.
#'
#' `roadmap_app()` returns the app object (for deployment or testing);
#' `run_roadmap()` runs it.
#'
#' @param csv Path to the milestones CSV, see [milestones-format]. If the file
#'   does not exist the app starts empty and creates it on the first change.
#'   To start from an example use `file.copy(roadmap_example(), "milestones.csv")`.
#' @param ... Passed on to [shiny::runApp()], e.g. `port` or `launch.browser`.
#'
#' @return `roadmap_app()`: a [shiny::shinyApp()] object. `run_roadmap()`:
#'   called for its side effect.
#' @seealso [export_snapshot()], [plot_roadmap()]
#' @export
#' @examples
#' if (interactive()) {
#'   tmp <- tempfile(fileext = ".csv")
#'   file.copy(roadmap_example(), tmp)
#'   run_roadmap(tmp)
#' }
run_roadmap <- function(csv = "milestones.csv", ...) {
  shiny::runApp(roadmap_app(csv), ...)
}

#' @rdname run_roadmap
#' @import shiny
#' @export
roadmap_app <- function(csv = "milestones.csv") {
  csv <- normalizePath(csv, mustWork = FALSE)
  html_out <- file.path(dirname(csv), "roadmap_snapshot.html")

  ui <- fluidPage(
    titlePanel("Readiness roadmap (TRL / MRL / FRL ...)"),
    tags$style(HTML(".well{padding:12px} .shiny-notification{font-size:14px}")),
    fluidRow(
      column(12, plotlyOutput("plot", height = "400px"),
             helpText("Drag a point sideways to move it. With several",
                      "dependencies the longest (latest) one decides the date;",
                      "it is drawn as the dark arrow. Dragging rewrites that",
                      "lag and everything after it moves along. Click a point",
                      "to edit it."))),
    fluidRow(
      column(6, wellPanel(h4("Selected milestone"), uiOutput("editor"))),
      column(6, wellPanel(
        h4("Add milestone"),
        fluidRow(
          column(6, selectizeInput("n_track", "Track (type to add a new one)",
                                   choices = NULL,
                                   options = list(create = TRUE))),
          column(6, numericInput("n_level", "Level", 1, min = 0, step = 1))),
        fluidRow(
          column(6, textInput("n_label", "Label (optional)", "")),
          column(6, selectInput("n_status", "Status",
                                c("planned", "achieved")))),
        selectizeInput("n_after", "Depends on (one or more)", choices = NULL,
                       multiple = TRUE),
        uiOutput("n_lags"),
        conditionalPanel("!input.n_after || input.n_after.length == 0",
                         textInput("n_date", "Fixed date (YYYY-MM-DD)",
                                   format(Sys.Date()))),
        textAreaInput("n_comment",
                      "Comment (shown on hover, multiple lines OK)",
                      "", rows = 3, width = "100%"),
        actionButton("add", "Add", class = "btn-primary"),
        actionButton("export", "Export HTML snapshot"))))
  )

  server <- function(input, output, session) {
    ms <- reactiveVal(read_milestones(csv))
    selected <- reactiveVal(NULL)
    redraw <- reactiveVal(0)

    save_ms <- function(df) {
      v <- validate_milestones(df)
      if (!v$ok) { showNotification(v$message, type = "error"); return(FALSE) }
      write_milestones(df, csv)
      ms(df)
      TRUE
    }

    # lag inputs, one per chosen predecessor; keeps what was typed, else stored
    lag_inputs <- function(prefix, preds, stored) {
      lapply(preds, function(p) {
        nm <- paste0(prefix, sanitize_id(p))
        cur <- isolate(input[[nm]])
        val <- if (!is.null(cur) && !is.na(cur)) cur else
          if (p %in% names(stored)) stored[[p]] else 0
        numericInput(nm, paste("Months after", p), value = val, min = 0,
                     step = 0.5)
      })
    }
    collect_after <- function(prefix, preds) {
      lags <- vapply(preds, function(p) {
        v <- input[[paste0(prefix, sanitize_id(p))]]
        if (is.null(v) || is.na(v)) 0 else v
      }, 0)
      format_dependencies(preds, lags)
    }

    observe({
      updateSelectizeInput(session, "n_track", choices = unique(ms()$track),
                           selected = isolate(input$n_track))
      updateSelectizeInput(session, "n_after", choices = ms()$id,
                           selected = isolate(input$n_after))
    })

    output$plot <- renderPlotly({
      redraw()
      df <- ms()
      if (nrow(df)) df <- resolve_milestones(df)
      plot_roadmap(df, editable = TRUE)
    })

    # ---- drag ---------------------------------------------------------------
    observeEvent(input$dragged, {
      d <- input$dragged
      r <- move_milestone(ms(), d$id, d$date)
      if (nzchar(r$message)) {
        showNotification(r$message, type = "warning")
        redraw(redraw() + 1)                 # snap the dragged point back
      } else if (!save_ms(r$df)) redraw(redraw() + 1)
    })

    # ---- select / edit --------------------------------------------------------
    observeEvent(event_data("plotly_click"), {
      p <- event_data("plotly_click")
      df <- ms()
      if (is.null(p) || !nrow(df)) return()
      if (p$curveNumber == 0) selected(df$id[p$pointNumber + 1])
    })

    sel_row <- reactive({
      id <- selected()
      df <- ms()
      if (is.null(id) || !(id %in% df$id)) NULL else df[df$id == id, ]
    })

    output$editor <- renderUI({
      r <- sel_row()
      if (is.null(r)) return(helpText("Click a point."))
      d <- parse_dependencies(r$after)
      tagList(
        strong(r$id),
        textInput("e_label", "Label", r$label),
        selectInput("e_status", "Status", c("planned", "achieved"), r$status),
        selectizeInput("e_after", "Depends on (one or more)",
                       choices = setdiff(ms()$id, r$id), selected = d$pred,
                       multiple = TRUE),
        uiOutput("e_lags"),
        conditionalPanel("!input.e_after || input.e_after.length == 0",
                         textInput("e_date", "Fixed date (YYYY-MM-DD)", r$date)),
        textAreaInput("e_comment", "Comment (multiple lines OK)", r$comment,
                      rows = 4, width = "100%"),
        actionButton("save", "Save", class = "btn-primary"),
        actionButton("delete", "Delete"))
    })

    output$e_lags <- renderUI({
      r <- sel_row()
      req(r)
      d <- parse_dependencies(r$after)
      lag_inputs(paste0("e_lag_", sanitize_id(r$id), "_"), input$e_after,
                 setNames(d$lag, d$pred))
    })
    output$n_lags <- renderUI(lag_inputs("n_lag_", input$n_after, c()))

    observeEvent(input$save, {
      r <- sel_row()
      req(r)
      df <- ms()
      i <- match(r$id, df$id)
      preds <- input$e_after
      df$label[i] <- input$e_label
      df$status[i] <- input$e_status
      df$comment[i] <- input$e_comment
      df$after[i] <- collect_after(paste0("e_lag_", sanitize_id(r$id), "_"),
                                   preds)
      df$date[i] <- if (length(preds)) "" else trimws(input$e_date)
      save_ms(df)
    })

    observeEvent(input$delete, {
      r <- sel_row()
      req(r)
      df <- ms()
      kids <- df$id[vapply(df$after,
                           function(a) r$id %in% parse_dependencies(a)$pred,
                           logical(1))]
      if (length(kids)) {
        showNotification(paste("Can't delete: still a predecessor of",
                               paste(kids, collapse = ", ")), type = "error")
        return()
      }
      selected(NULL)
      save_ms(df[df$id != r$id, ])
    })

    # ---- add ------------------------------------------------------------------
    observeEvent(input$add, {
      req(nzchar(input$n_track))
      df <- ms()
      id <- paste0(input$n_track, input$n_level)
      if (id %in% df$id) {
        showNotification(paste(id, "exists already"), type = "error")
        return()
      }
      preds <- input$n_after
      row <- data.frame(
        id = id, track = input$n_track, level = as.character(input$n_level),
        label = input$n_label,
        date = if (length(preds)) "" else trimws(input$n_date),
        after = collect_after("n_lag_", preds),
        status = input$n_status, comment = input$n_comment,
        stringsAsFactors = FALSE)
      save_ms(rbind(df, row))
    })

    observeEvent(input$export, {
      export_snapshot(csv, html_out)
      showNotification(paste("Wrote", html_out))
    })
  }

  shinyApp(ui, server)
}

# Make an id safe to use inside a shiny input id.
#' @noRd
sanitize_id <- function(x) gsub("[^A-Za-z0-9]", "_", x)
