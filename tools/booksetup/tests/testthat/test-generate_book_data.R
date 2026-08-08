create_minimal_book <- function(dir) {
  writeLines(c(
    "project:",
    "  type: book",
    "book:",
    "  chapters:",
    "    - simple.qmd"
  ), file.path(dir, "_quarto.yml"))

  writeLines(c(
    "---",
    "title: Simple",
    "---",
    "",
    "# Intro",
    "",
    "```{r}",
    "x <- 1 + 1",
    "```",
    "",
    "```{r}",
    "#| eval: false",
    "y <- x * 2",
    "```"
  ), file.path(dir, "simple.qmd"))
}

test_that("generated script runs without error on a minimal book", {
  book_dir <- file.path(tempdir(), "mini_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_minimal_book(book_dir)

  out <- tempfile("data_script_", fileext = ".R")
  on.exit(unlink(out), add = TRUE)

  script_path <- build_data_script(book_dir, output = out,
                                   skip_existing = FALSE,
                                   python_sync = FALSE,
                                   chunk_times = FALSE)

  old_home <- Sys.getenv("HOME")
  Sys.setenv(HOME = tempdir())
  on.exit(Sys.setenv(HOME = old_home), add = TRUE, after = FALSE)

  expect_error(source(script_path, local = new.env(), echo = FALSE), NA)
})

test_that("chunk_times mode writes a CSV with one row per chunk", {
  book_dir <- file.path(tempdir(), "mini_book_chunk")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_minimal_book(book_dir)

  out <- file.path(tempdir(), "chunk_timed.R")
  on.exit(unlink(out), add = TRUE)

  script_path <- build_data_script(book_dir, output = out,
                                   skip_existing = FALSE,
                                   python_sync = FALSE,
                                   chunk_times = TRUE)

  old_home <- Sys.getenv("HOME")
  Sys.setenv(HOME = tempdir())
  on.exit(Sys.setenv(HOME = old_home), add = TRUE, after = FALSE)

  expect_error(source(script_path, local = new.env(), echo = FALSE), NA)

  csv_file <- sub("\\.R$", "_chunks.csv", out)
  on.exit(unlink(csv_file), add = TRUE)
  expect_true(file.exists(csv_file))

  df <- read.csv(csv_file, stringsAsFactors = FALSE)
  expect_equal(nrow(df), 2L)
  expect_equal(df$chapter, rep("simple", 2L))
  expect_equal(df$chunk, 1:2)
  expect_true(all(df$elapsed >= 0))
  expect_true(all(is.na(df$error) | df$error == ""))
  expect_true(all(df$start_line < df$end_line))
})

test_that("chunk_times mode records errors without aborting the script", {
  book_dir <- file.path(tempdir(), "mini_book_err")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)

  writeLines(c(
    "project:",
    "  type: book",
    "book:",
    "  chapters:",
    "    - error.qmd"
  ), file.path(book_dir, "_quarto.yml"))

  writeLines(c(
    "---",
    "title: Error",
    "---",
    "",
    "```{r}",
    "stop('intentional error')",
    "```",
    "",
    "```{r}",
    "x <- 1",
    "```"
  ), file.path(book_dir, "error.qmd"))

  out <- file.path(tempdir(), "chunk_err.R")
  on.exit(unlink(out), add = TRUE)

  script_path <- build_data_script(book_dir, output = out,
                                   skip_existing = FALSE,
                                   python_sync = FALSE,
                                   chunk_times = TRUE)

  old_home <- Sys.getenv("HOME")
  Sys.setenv(HOME = tempdir())
  on.exit(Sys.setenv(HOME = old_home), add = TRUE, after = FALSE)

  expect_error(source(script_path, local = new.env(), echo = FALSE),
               "Some chapters failed")

  csv_file <- sub("\\.R$", "_chunks.csv", out)
  on.exit(unlink(csv_file), add = TRUE)
  df <- read.csv(csv_file, stringsAsFactors = FALSE)
  expect_equal(nrow(df), 2L)
  expect_match(df$error[1], "intentional error")
  expect_true(df$error[2] == "" || is.na(df$error[2]))
})

test_that("skip_existing avoids re-running chapters with data", {
  book_dir <- file.path(tempdir(), "mini_book_skip")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_minimal_book(book_dir)

  fake_data_dir <- file.path(tempdir(), "sitsbook", "tempdir", "R", "simple")
  dir.create(fake_data_dir, showWarnings = FALSE, recursive = TRUE)
  writeLines("x", file.path(fake_data_dir, "file.txt"))

  out <- file.path(tempdir(), "skip_script.R")
  on.exit(unlink(out), add = TRUE)

  script_path <- build_data_script(book_dir, output = out,
                                   skip_existing = TRUE,
                                   python_sync = FALSE,
                                   chunk_times = FALSE)

  old_home <- Sys.getenv("HOME")
  Sys.setenv(HOME = tempdir())
  on.exit(Sys.setenv(HOME = old_home), add = TRUE, after = FALSE)

  expect_error(source(script_path, local = new.env(), echo = FALSE), NA)

  log_file <- sub("\\.R$", ".log", out)
  on.exit(unlink(log_file), add = TRUE)
  log <- paste(readLines(log_file, warn = FALSE), collapse = "\n")
  expect_match(log, "skipping")
})
