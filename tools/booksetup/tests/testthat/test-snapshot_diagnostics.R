# Tests for snapshot_info(): registry diagnostics for the .snapshots/ cache
# (per-chunk snapshot size, variable count, and "missing when expected"
# staleness signal).

test_that("snapshot_info marks eval:true chunks as not_applicable", {
  reg <- list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = TRUE)
  )
  snap_dir <- tempfile("snap_")
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)

  info <- snapshot_info(reg, snap_dir)
  expect_equal(info$status, "not_applicable")
  expect_equal(info$n_vars, 0L)
  expect_equal(info$size_bytes, 0)
})

test_that("snapshot_info marks errored chunks as not_applicable", {
  reg <- list(
    "a:1" = list(status = "error", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = FALSE, error = "boom")
  )
  snap_dir <- tempfile("snap_")
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)

  info <- snapshot_info(reg, snap_dir)
  expect_equal(info$status, "not_applicable")
})

test_that("snapshot_info flags a missing snapshot directory for an ok eval:false chunk", {
  reg <- list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = FALSE)
  )
  snap_dir <- tempfile("snap_")
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)
  dir.create(snap_dir)

  info <- snapshot_info(reg, snap_dir)
  expect_equal(info$status, "missing")
  expect_equal(info$n_vars, 0L)
  expect_equal(info$size_bytes, 0)
})

test_that("snapshot_info flags an existing-but-empty snapshot directory", {
  reg <- list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = FALSE)
  )
  snap_dir <- tempfile("snap_")
  dir.create(file.path(snap_dir, "a:1"), recursive = TRUE)
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)

  info <- snapshot_info(reg, snap_dir)
  expect_equal(info$status, "empty")
  expect_equal(info$n_vars, 0L)
})

test_that("snapshot_info reports variable count and total size for a valid snapshot", {
  reg <- list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = FALSE)
  )
  snap_dir <- tempfile("snap_")
  key_dir <- file.path(snap_dir, "a:1")
  dir.create(key_dir, recursive = TRUE)
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)

  saveRDS(1:10, file.path(key_dir, "foo.rds"))
  saveRDS(letters, file.path(key_dir, "bar.rds"))

  info <- snapshot_info(reg, snap_dir)
  expect_equal(info$status, "ok")
  expect_equal(info$n_vars, 2L)
  expected_size <- sum(file.size(file.path(key_dir, c("foo.rds", "bar.rds"))))
  expect_equal(info$size_bytes, expected_size)
})

test_that("snapshot_info handles multiple chunks across chapters", {
  reg <- list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = TRUE),
    "a:2" = list(status = "ok", hash = "h2", elapsed = 1, lines = "3-4",
                 label = "y", eval = FALSE),
    "b:1" = list(status = "ok", hash = "h3", elapsed = 1, lines = "1-2",
                 label = "z", eval = FALSE)
  )
  snap_dir <- tempfile("snap_")
  dir.create(file.path(snap_dir, "a:2"), recursive = TRUE)
  saveRDS(42, file.path(snap_dir, "a:2", "n.rds"))
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)
  # "b:1" has no snapshot directory at all -> missing

  info <- snapshot_info(reg, snap_dir)
  expect_equal(nrow(info), 3L)
  expect_equal(info$chapter, c("a", "a", "b"))
  expect_equal(info$chunk, c(1L, 2L, 1L))
  expect_equal(info$status, c("not_applicable", "ok", "missing"))
  expect_equal(info$n_vars, c(0L, 1L, 0L))
})

test_that("snapshot_info handles an empty registry", {
  snap_dir <- tempfile("snap_")
  info <- snapshot_info(list(), snap_dir)
  expect_equal(nrow(info), 0L)
  expect_named(info, c("chapter", "chunk", "key", "n_vars", "size_bytes", "status"))
})

test_that("write_snapshot_summary writes a parseable CSV", {
  reg <- list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = FALSE)
  )
  snap_dir <- tempfile("snap_")
  key_dir <- file.path(snap_dir, "a:1")
  dir.create(key_dir, recursive = TRUE)
  saveRDS(1, file.path(key_dir, "v.rds"))
  on.exit(unlink(snap_dir, recursive = TRUE), add = TRUE)

  out_csv <- tempfile("snapshot_summary_", fileext = ".csv")
  on.exit(unlink(out_csv), add = TRUE)

  write_snapshot_summary(reg, snap_dir, out_csv)
  expect_true(file.exists(out_csv))
  df <- utils::read.csv(out_csv, stringsAsFactors = FALSE)
  expect_equal(df$status, "ok")
  expect_equal(df$n_vars, 1L)
})

test_that("generate_book_data writes a snapshot_summary.csv alongside chunk_summary.csv", {
  book_dir <- file.path(tempdir(), "snapdiag_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)

  writeLines(c(
    "project:", "  type: book", "book:", "  chapters:",
    "    - snapdiag.qmd"
  ), file.path(book_dir, "_quarto.yml"))

  writeLines(c(
    "---", "title: Snapdiag", "---", "",
    "```{r}", "#| eval: false", "x <- 1", "```",
    "", "```{r}", "y <- x + 1", "```"
  ), file.path(book_dir, "snapdiag.qmd"))

  reg <- file.path(tempdir(), "snapdiag_registry.yaml")
  log <- file.path(tempdir(), "snapdiag.log")
  on.exit(unlink(c(reg, log)), add = TRUE)

  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log
  ))

  summary_csv <- file.path(dirname(reg), "snapshot_summary.csv")
  expect_true(file.exists(summary_csv))
  df <- utils::read.csv(summary_csv, stringsAsFactors = FALSE)
  expect_true("snapdiag:1" %in% paste0(df$chapter, ":", df$chunk))
})
