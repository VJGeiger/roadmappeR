test_that("quarterly ticks cover the range and show the year on Q1", {
  qt <- quarter_ticks(as.Date(c("2026-02-10", "2027-01-05")))
  expect_equal(qt$vals, c("2026-01-01", "2026-04-01", "2026-07-01",
                          "2026-10-01", "2027-01-01"))
  expect_match(qt$text[1], "2026")     # first tick always shows the year
  expect_equal(qt$text[2], "Q2")
  expect_match(qt$text[5], "2027")
})

test_that("comments become escaped, wrapped, multi-line hover html", {
  expect_equal(comment_html(""), "")
  h <- comment_html("line one\nline two\n\n<b>four</b>")
  expect_match(h, "line one<br>line two<br><br>&lt;b&gt;four&lt;/b&gt;",
               fixed = TRUE)
  long <- paste(rep("word", 30), collapse = " ")
  expect_gt(lengths(regmatches(comment_html(long),
                               gregexpr("<br>", comment_html(long)))), 1)
})

test_that("plot_roadmap builds a plotly widget", {
  skip_if_not_installed("plotly")
  ms <- read_milestones(roadmap_example())
  p <- plot_roadmap(ms)
  expect_s3_class(p, "plotly")
  b <- plotly::plotly_build(p)
  expect_length(b$x$data, 1)                      # one marker trace
  expect_equal(length(b$x$data[[1]]$x), nrow(ms))
  expect_s3_class(plot_roadmap(ms, editable = TRUE), "htmlwidget")
  expect_s3_class(plot_roadmap(ms[0, ]), "plotly")
})

test_that("the app object can be created", {
  skip_if_not_installed("shiny")
  expect_s3_class(roadmap_app(tempfile(fileext = ".csv")), "shiny.appobj")
})

test_that("export_snapshot writes a standalone html file", {
  skip_on_cran()
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  out <- tempfile(fileext = ".html")
  expect_equal(export_snapshot(roadmap_example(), out), out)
  expect_true(file.exists(out))
  expect_gt(file.size(out), 1e5)

  bad <- tempfile(fileext = ".csv")
  writeLines(c("id,track,level,label,date,after,status,comment",
               "A,T,1,,2026-01-01,B:1,planned,",
               "B,T,2,,,A:1,planned,"), bad)
  expect_error(export_snapshot(bad, out), "Circular")
})
