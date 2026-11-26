test_that("a missing file reads as an empty data frame", {
  df <- read_milestones(tempfile(fileext = ".csv"))
  expect_equal(nrow(df), 0)
  expect_named(df, c("id", "track", "level", "label", "date", "after",
                     "status", "comment"))
})

test_that("write/read round-trips, including multiline comments", {
  ms <- read_milestones(roadmap_example())
  expect_true(any(grepl("\n", ms$comment, fixed = TRUE)))
  tmp <- tempfile(fileext = ".csv")
  write_milestones(ms, tmp)
  expect_identical(read_milestones(tmp), ms)
  expect_false(file.exists(paste0(tmp, ".tmp")))
})

test_that("old files with a lag_months column are converted", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("id,track,level,label,date,after,lag_months,status,comment",
               "A,T,1,,2026-01-01,,,planned,",
               "B,T,2,,,A,6,planned,"), tmp)
  ms <- read_milestones(tmp)
  expect_equal(ms$after, c("", "A:6"))
  expect_false("lag_months" %in% names(ms))
})

test_that("Windows line breaks in comments are normalised", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("id,track,level,label,date,after,status,comment",
               "A,T,1,,2026-01-01,,planned,\"one\r\ntwo\""), tmp)
  expect_equal(read_milestones(tmp)$comment, "one\ntwo")
})
