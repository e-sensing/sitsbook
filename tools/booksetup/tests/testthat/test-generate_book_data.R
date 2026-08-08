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

  out <- file.path(tempdir(), "mini_run.R")
  reg <- file.path(tempdir(), "mini_registry.yaml")
  on.exit(unlink(c(out, reg)), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, registry = reg,
                                   python_sync = FALSE)
  expect_error(quiet_source(script_path), NA)

  expect_true(file.exists(reg))
  registry <- registry_read(reg)
  expect_length(registry, 2L)
  expect_named(registry, c("simple:1", "simple:2"))
})

test_that("registry causes completed chunks to be skipped on second run", {
  book_dir <- file.path(tempdir(), "skip_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_minimal_book(book_dir)

  out <- file.path(tempdir(), "skip_run.R")
  log <- file.path(tempdir(), "skip_run.log")
  reg <- file.path(tempdir(), "skip_registry.yaml")
  on.exit(unlink(c(out, log, reg)), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, registry = reg,
                                   python_sync = FALSE)
  expect_error(quiet_source(script_path), NA)

  # Second run with the same registry
  script_path2 <- build_data_script(book_dir, output = out, registry = reg,
                                    python_sync = FALSE)
  expect_error(quiet_source(script_path2), NA)

  expect_true(file.exists(log))
  events <- read_event_log(log)
  event_types <- vapply(events, function(e) e$event %||% "", character(1L))
  expect_true("chunk_skip" %in% event_types)
})

test_that("failed chunks are recorded with status = error and always retried", {
  book_dir <- file.path(tempdir(), "fail_book")
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

  out <- file.path(tempdir(), "fail_run.R")
  reg <- file.path(tempdir(), "fail_registry.yaml")
  on.exit(unlink(c(out, reg)), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, registry = reg,
                                   python_sync = FALSE)

  expect_error(quiet_source(script_path),
               "Some chapters failed")

  registry <- registry_read(reg)
  expect_length(registry, 1L)
  expect_equal(registry[["error:1"]]$status, "error")
  expect_match(registry[["error:1"]]$error, "intentional error")

  # Re-run: chunk 1 fails again (always retried since status is "error"),
  # chunk 2 is never reached
  expect_error(quiet_source(script_path),
               "Some chapters failed")
  registry2 <- registry_read(reg)
  expect_length(registry2, 1L)
  expect_equal(registry2[["error:1"]]$status, "error")
})

test_that("an error in one chapter does not stop the next chapter", {
  book_dir <- file.path(tempdir(), "two_chapter_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)

  writeLines(c(
    "project:",
    "  type: book",
    "book:",
    "  chapters:",
    "    - error.qmd",
    "    - simple.qmd"
  ), file.path(book_dir, "_quarto.yml"))

  writeLines(c(
    "---",
    "title: Error",
    "---",
    "",
    "```{r}",
    "stop('intentional error')",
    "```"
  ), file.path(book_dir, "error.qmd"))

  writeLines(c(
    "---",
    "title: Simple",
    "---",
    "",
    "```{r}",
    "z <- 42",
    "```"
  ), file.path(book_dir, "simple.qmd"))

  out <- file.path(tempdir(), "two_chapter_run.R")
  reg <- file.path(tempdir(), "two_chapter_registry.yaml")
  on.exit(unlink(c(out, reg)), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, registry = reg,
                                   python_sync = FALSE)

  expect_error(quiet_source(script_path),
               "Some chapters failed")

  registry <- registry_read(reg)
  expect_length(registry, 2L)
  expect_named(registry, c("error:1", "simple:1"))
  expect_equal(registry[["error:1"]]$status, "error")
  expect_equal(registry[["simple:1"]]$status, "ok")
})

test_that("editing a chunk changes its hash and re-runs only that chunk", {
  book_dir <- file.path(tempdir(), "edit_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_minimal_book(book_dir)

  out <- file.path(tempdir(), "edit_run.R")
  reg <- file.path(tempdir(), "edit_registry.yaml")
  on.exit(unlink(c(out, reg)), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, registry = reg,
                                   python_sync = FALSE)
  expect_error(quiet_source(script_path), NA)

  old_hash <- registry_read(reg)[["simple:1"]]$hash

  # Edit the first chunk
  writeLines(c(
    "---",
    "title: Simple",
    "---",
    "",
    "# Intro",
    "",
    "```{r}",
    "x <- 1 + 1 + 1",
    "```",
    "",
    "```{r}",
    "#| eval: false",
    "y <- x * 2",
    "```"
  ), file.path(book_dir, "simple.qmd"))

  script_path2 <- build_data_script(book_dir, output = out, registry = reg,
                                     python_sync = FALSE)
  expect_error(quiet_source(script_path2), NA)

  new_registry <- registry_read(reg)
  expect_false(identical(new_registry[["simple:1"]]$hash, old_hash))
  expect_identical(new_registry[["simple:2"]]$hash, registry_read(reg)[["simple:2"]]$hash)
})

test_that("chapters are isolated from each other in the generated script", {
  book_dir <- system.file("extdata", "isolation_book", package = "booksetup")
  out <- file.path(tempdir(), "isolation_run.R")
  reg <- file.path(tempdir(), "isolation_registry.yaml")
  on.exit(unlink(c(out, reg)), add = TRUE)

  script_path <- build_data_script(book_dir, output = out, registry = reg,
                                   python_sync = FALSE)
  expect_error(quiet_source(script_path), NA)
})

test_that("run_chunk always runs eval: true chunks even when in registry", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  on.exit(unlink(reg_path), add = TRUE)

  registry <- list(
    "simple:1" = list(
      hash = "abc",
      elapsed = 0.1,
      lines = "1-2",
      label = "chunk_1",
      eval = TRUE
    )
  )
  yaml::write_yaml(registry, reg_path)

  log_path <- tempfile("log_")
  on.exit(unlink(log_path), add = TRUE)

  env <- new.env()
  source(system.file("runtime.R", package = "booksetup"), local = env)
  env$booksetup_registry <- registry_read(reg_path)
  env$registry_file <- reg_path
  env$chapter_times <- numeric()
  env$errors <- character()
  env$log_con <- file(log_path, "w")
  on.exit(close(env$log_con), add = TRUE)

  expect_error(
    suppressMessages(env$run_chunk(
      chapter_name = "simple",
      chunk_i = 1L,
      n_chunks = 1L,
      start_line = 1L,
      end_line = 2L,
      label = "chunk_1",
      hash = "abc",
      eval = TRUE,
      env = new.env(),
      code = "stop('must run')"
    )),
    "must run"
  )

  expect_equal(length(env$errors), 0L)
  updated <- registry_read(reg_path)
  expect_equal(updated[["simple:1"]]$hash, "abc")
})

test_that("run_chunk fixes a stale registry label on skip", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  on.exit(unlink(reg_path), add = TRUE)

  # Registry as it was left by the bug: wrong label, correct hash.
  registry <- list(
    "intro_visualisation:12" = list(
      hash = "0269badff6c8629e8ea6425f2fa1700e",
      elapsed = 0.123,
      lines = "401-404",
      label = "}"
    )
  )
  yaml::write_yaml(registry, reg_path)

  log_path <- tempfile("log_")
  on.exit(unlink(log_path), add = TRUE)

  env <- new.env()
  source(system.file("runtime.R", package = "booksetup"), local = env)
  env$booksetup_registry <- registry_read(reg_path)
  env$registry_file <- reg_path
  env$chapter_times <- numeric()
  env$errors <- character()
  env$log_con <- file(log_path, "w")
  on.exit(close(env$log_con), add = TRUE)

  expect_message(
    env$run_chunk(
      chapter_name = "intro_visualisation",
      chunk_i = 12L,
      n_chunks = 16L,
      start_line = 401L,
      end_line = 404L,
      label = "chunk_12",
      hash = "0269badff6c8629e8ea6425f2fa1700e",
      eval = FALSE,
      env = new.env(),
      code = "stop('should not run')"
    ),
    "SKIPPED"
  )

  updated <- registry_read(reg_path)
  expect_equal(updated[["intro_visualisation:12"]]$label, "chunk_12")
  expect_equal(updated[["intro_visualisation:12"]]$hash,
               "0269badff6c8629e8ea6425f2fa1700e")
})
