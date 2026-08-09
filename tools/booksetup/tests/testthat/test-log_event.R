test_that("log_event writes a valid flow-style YAML line per event", {
  log_path <- tempfile("log_")
  on.exit(unlink(log_path), add = TRUE)
  con <- file(log_path, "w")

  log_event(con, "chunk_ok", chapter = "intro", chunk = 3L, elapsed = 1.5, eval = TRUE)
  close(con)

  txt <- readLines(log_path, warn = FALSE)
  expect_length(txt, 1L)
  expect_match(txt, "^- \\{")

  events <- yaml::read_yaml(log_path)
  expect_length(events, 1L)
  expect_equal(events[[1L]]$event, "chunk_ok")
  expect_equal(events[[1L]]$chapter, "intro")
  expect_equal(events[[1L]]$chunk, 3L)
  expect_equal(events[[1L]]$eval, TRUE)
})

test_that("log_event escapes quotes, backslashes, and newlines in messages", {
  log_path <- tempfile("log_")
  on.exit(unlink(log_path), add = TRUE)
  con <- file(log_path, "w")

  tricky <- "line one\nline \"two\" with \\backslash\\ and\ttab"
  log_event(con, "chunk_error", chapter = "x", chunk = 1L, message = tricky)
  close(con)

  events <- yaml::read_yaml(log_path)
  expect_equal(events[[1L]]$message, tricky)
})

test_that("the whole log file is a single parseable YAML sequence", {
  log_path <- tempfile("log_")
  on.exit(unlink(log_path), add = TRUE)
  con <- file(log_path, "w")

  log_event(con, "run_start", n_chapters = 2L)
  log_event(con, "chapter_start", chapter = "a", index = 1L, total = 2L)
  log_event(con, "chunk_ok", chapter = "a", chunk = 1L, elapsed = 0.5)
  log_event(con, "chapter_end", chapter = "a", elapsed = 0.5)
  close(con)

  events <- yaml::read_yaml(log_path)
  expect_length(events, 4L)
  expect_equal(vapply(events, `[[`, character(1L), "event"),
               c("run_start", "chapter_start", "chunk_ok", "chapter_end"))
})

test_that("a chunk raising only a warning logs a chunk_warning event and still succeeds", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  log_path <- tempfile("log_")
  img_dir <- tempfile("images_")
  on.exit(unlink(c(reg_path, log_path)), add = TRUE)
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  state <- new_run_state(
    registry_file = reg_path,
    log_file = log_path,
    image_dir = img_dir,
    image_width = 400L,
    image_height = 300L,
    image_res = 72L,
    n_chapters = 1L
  )
  on.exit(close_run_state(state), add = TRUE)

  # Use capture_messages() rather than expect_message() so that the second
  # (chunk-ok summary) message emitted by run_chunk() is also captured
  # instead of leaking to the console (expect_message() only intercepts the
  # first matching message).
  msgs <- testthat::capture_messages(
    run_chunk(
      state = state,
      chapter_name = "warn_chapter",
      chunk_i = 1L,
      n_chunks = 1L,
      start_line = 1L,
      end_line = 2L,
      label = "chunk_1",
      hash = "abc",
      eval = TRUE,
      env = new.env(),
      code = "warning('be careful'); 1 + 1"
    )
  )
  expect_true(any(grepl("WARNING", msgs)))

  registry <- registry_read(reg_path)
  expect_equal(registry[["warn_chapter:1"]]$status, "ok")

  events <- yaml::read_yaml(log_path)
  event_types <- vapply(events, `[[`, character(1L), "event")
  expect_true("chunk_warning" %in% event_types)
  warn_event <- events[[which(event_types == "chunk_warning")[1L]]]
  expect_match(warn_event$message, "be careful")
})

test_that("a chunk that errors logs a chunk_error event", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  log_path <- tempfile("log_")
  img_dir <- tempfile("images_")
  on.exit(unlink(c(reg_path, log_path)), add = TRUE)
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  state <- new_run_state(
    registry_file = reg_path,
    log_file = log_path,
    image_dir = img_dir,
    image_width = 400L,
    image_height = 300L,
    image_res = 72L,
    n_chapters = 1L
  )
  on.exit(close_run_state(state), add = TRUE)

  expect_error(
    suppressMessages(run_chunk(
      state = state,
      chapter_name = "err_chapter",
      chunk_i = 1L,
      n_chunks = 1L,
      start_line = 1L,
      end_line = 2L,
      label = "chunk_1",
      hash = "abc",
      eval = TRUE,
      env = new.env(),
      code = "stop('boom')"
    )),
    "boom"
  )

  registry <- registry_read(reg_path)
  expect_equal(registry[["err_chapter:1"]]$status, "error")
  expect_match(registry[["err_chapter:1"]]$error, "boom")

  events <- yaml::read_yaml(log_path)
  event_types <- vapply(events, `[[`, character(1L), "event")
  expect_true("chunk_error" %in% event_types)
})
