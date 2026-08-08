test_that("build_data_script writes a parseable R file", {
  book_dir <- system.file("extdata", "integration_book", package = "booksetup")
  out <- tempfile("data_script_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, python_sync = FALSE)

  expect_true(file.exists(script_path))
  parsed <- parse(file = script_path)
  expect_type(parsed, "expression")
})

test_that("generated script contains runtime helpers and run_* calls", {
  book_dir <- system.file("extdata", "integration_book", package = "booksetup")
  out <- tempfile("data_script_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  build_data_script(book_dir, output = out, python_sync = FALSE)
  script <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_true(grepl("run_chapter", script))
  expect_true(grepl("run_chunk", script))
  expect_true(grepl("registry_read", script))
  expect_true(grepl("registry_write", script))
  expect_false(grepl("skip_existing", script))
  expect_false(grepl("make_skip_lines", script))
})

test_that("build_data_script uses a timestamped default output under tempdir/", {
  book_dir <- system.file("extdata", "integration_book", package = "booksetup")
  old_wd <- setwd(tempdir())
  on.exit(setwd(old_wd), add = TRUE)

  script_path <- build_data_script(book_dir, python_sync = FALSE)
  on.exit(unlink(script_path), add = TRUE)

  expect_true(file.exists(script_path))
  expect_match(dirname(script_path), "tempdir$")
  expect_match(basename(script_path),
               "^generate_book_data_[0-9]{8}_[0-9]{6}\\.R$")
})

test_that("build_data_script excludes chapters", {
  book_dir <- system.file("extdata", "integration_book", package = "booksetup")
  out <- tempfile("exclude_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  build_data_script(book_dir, output = out, exclude = "simple",
                    python_sync = FALSE)
  script <- paste(readLines(out, warn = FALSE), collapse = "\n")

  expect_false(grepl('run_chapter("simple"', script, fixed = TRUE))
  expect_true(grepl('run_chapter("empty"', script, fixed = TRUE))
})

test_that("build_data_script warns on unknown excluded chapters", {
  book_dir <- system.file("extdata", "integration_book", package = "booksetup")
  out <- tempfile("exclude_warn_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  expect_warning(
    build_data_script(book_dir, output = out,
                      exclude = c("simple", "not_a_chapter"),
                      python_sync = FALSE),
    "not_a_chapter"
  )
})
