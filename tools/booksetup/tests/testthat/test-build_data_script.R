test_that("build_data_script writes a parseable R file", {
  book_dir <- system.file("extdata", package = "booksetup")
  out <- tempfile("data_script_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, skip_existing = FALSE,
                                   chunk_times = FALSE)

  expect_true(file.exists(script_path))
  parsed <- parse(file = script_path)
  expect_type(parsed, "expression")
})

test_that("generated script contains expected chapter code and progress messages", {
  book_dir <- system.file("extdata", package = "booksetup")
  out <- tempfile("data_script_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  build_data_script(book_dir, output = out, skip_existing = FALSE,
                    python_sync = FALSE, chunk_times = FALSE)
  script <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_true(grepl("sits_regularize", script))
  expect_true(grepl("Starting book data generation", script))
  expect_true(grepl("elapsed:", script))
})

test_that("per-chunk timing block is generated when chunk_times = TRUE", {
  book_dir <- system.file("extdata", package = "booksetup")
  out <- tempfile("data_script_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  build_data_script(book_dir, output = out, skip_existing = FALSE,
                    python_sync = FALSE, chunk_times = TRUE)
  script <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_true(grepl("chunk_start_line", script))
  expect_true(grepl("chunk_log", script))
  expect_true(grepl("Top 10 slowest chunks", script))
})
