example_ms <- function() read_milestones(roadmap_example())

test_that("parse and format dependencies round-trip", {
  d <- parse_dependencies("TRL4:5; MRL3:2.5")
  expect_equal(d$pred, c("TRL4", "MRL3"))
  expect_equal(d$lag, c(5, 2.5))
  expect_equal(format_dependencies(d$pred, d$lag), "TRL4:5;MRL3:2.5")
  expect_equal(nrow(parse_dependencies("")), 0)
  expect_equal(format_dependencies(character(), numeric()), "")
  expect_equal(parse_dependencies("A")$lag, 0)
})

test_that("the example data is valid", {
  expect_true(validate_milestones(example_ms())$ok)
})

test_that("the longest dependency decides the date", {
  r <- resolve_milestones(example_ms())
  get <- function(id, col) r[[col]][r$id == id]
  expect_equal(get("TRL5", "when"), as.Date("2027-09-30"))   # TRL4 + 12
  expect_equal(get("TRL7", "driver"), "TRL6")                # TRL6+14 > MRL6+1
  expect_equal(get("FRL6", "driver"), "TRL6")                # TRL6+3 > FRL5+12
  expect_equal(get("FRL6", "when"), as.Date("2028-10-30"))
  expect_equal(get("TRL3", "driver"), "")                    # fixed date
})

test_that("month arithmetic clamps to the end of the month", {
  expect_equal(add_months(as.Date("2026-01-31"), 1), as.Date("2026-02-28"))
  expect_equal(add_months(as.Date("2026-11-15"), 3), as.Date("2027-02-15"))
  expect_equal(add_months(as.Date("2026-01-01"), 0.5), as.Date("2026-01-16"))
})

test_that("validation catches the usual mistakes", {
  ms <- example_ms()

  d <- ms; d$after[d$id == "TRL4"] <- "FRL6:1"
  expect_match(validate_milestones(d)$message, "Circular")

  d <- ms; d$after[d$id == "TRL5"] <- "NOPE:3"
  expect_match(validate_milestones(d)$message, "unknown predecessor")

  d <- ms; d$after[d$id == "TRL5"] <- "TRL5:3"
  expect_match(validate_milestones(d)$message, "itself")

  d <- ms; d$after[d$id == "TRL5"] <- "TRL4:-2"
  expect_match(validate_milestones(d)$message, "lags")

  d <- ms; d$date[d$id == "TRL3"] <- ""
  expect_match(validate_milestones(d)$message, "needs a predecessor")

  d <- rbind(ms, ms[1, ])
  expect_match(validate_milestones(d)$message, "Duplicate")
})

test_that("dragging a dependent milestone rewrites the longest lag", {
  ms <- example_ms()
  res <- move_milestone(ms, "TRL7", "2029-11-30")        # 2 months later
  expect_equal(res$message, "")
  expect_equal(res$df$after[res$df$id == "TRL7"], "TRL6:16;MRL6:1")
})

test_that("dragging a fixed-date milestone shifts everything after it", {
  ms <- example_ms()
  res <- move_milestone(ms, "TRL4", "2026-12-31")
  expect_equal(res$df$date[res$df$id == "TRL4"], "2026-12-31")
  r <- resolve_milestones(res$df)
  expect_equal(r$when[r$id == "MRL4"], as.Date("2027-05-31"))  # +5 months
  expect_equal(r$when[r$id == "FRL4"], as.Date("2027-02-28"))  # +2 months
})

test_that("invalid drags are refused and leave the data unchanged", {
  ms <- example_ms()
  res <- move_milestone(ms, "TRL5", "2026-01-01")        # before TRL4
  expect_match(res$message, "earlier than its predecessor")
  expect_identical(res$df, ms)

  res <- move_milestone(ms, "TRL7", "2028-09-01")        # before MRL6 + 1
  expect_match(res$message, "MRL6")
  expect_identical(res$df, ms)

  expect_match(move_milestone(ms, "XXX", "2026-01-01")$message, "Unknown")
})
