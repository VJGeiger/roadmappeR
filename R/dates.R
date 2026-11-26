.days_per_month <- 30.4375

# Add a (possibly fractional) number of months to a date: whole months by
# calendar (day clamped to the length of the target month), the remainder as
# days.
#' @noRd
add_months <- function(d, n) {
  whole <- trunc(n)
  frac  <- n - whole
  lt <- as.POSIXlt(d)
  total <- lt$year * 12 + lt$mon + whole
  lt$year <- total %/% 12
  lt$mon  <- total %% 12
  first <- as.Date(sprintf("%04d-%02d-01", lt$year + 1900, lt$mon + 1))
  nxt <- seq(first, by = "month", length.out = 2)[2]
  lt$mday <- min(lt$mday, as.integer(nxt - first))
  as.Date(lt) + round(frac * .days_per_month)
}

#' @noRd
months_between <- function(from, to) {
  round(as.numeric(to - from) / .days_per_month, 1)
}
