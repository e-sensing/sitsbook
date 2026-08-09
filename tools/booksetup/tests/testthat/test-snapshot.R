# Tests for chunk environment snapshot/restore.
#
# The core bug: when an eval:false chunk is skipped (hash match), its
# variables don't exist in the session, breaking downstream eval:true chunks.
# The fix: snapshot new variables after eval:false execution, restore on skip.

create_bridge_book <- function(dir) {
  writeLines(c(
    "project:",
    "  type: book",
    "book:",
    "  chapters:",
    "    - bridge.qmd"
  ), file.path(dir, "_quarto.yml"))

  writeLines(c(
    "---",
    "title: Bridge",
    "---",
    "",
    "```{r}",
    "#| eval: false",
    "x <- 42",
    "```",
    "",
    "```{r}",
    "y <- x + 1",
    "```"
  ), file.path(dir, "bridge.qmd"))
}

# Test A: the fundamental use case
test_that("skipped eval:false chunk restores variables for downstream chunks", {
  book_dir <- file.path(tempdir(), "bridge_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_bridge_book(book_dir)

  reg <- file.path(tempdir(), "bridge_registry.yaml")
  log <- file.path(tempdir(), "bridge.log")
  on.exit(unlink(c(reg, log)), add = TRUE)

  # First run: both chunks execute; x is snapshotted
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log
  ))

  registry1 <- registry_read(reg)
  expect_equal(registry1[["bridge:1"]]$status, "ok")
  expect_equal(registry1[["bridge:2"]]$status, "ok")

  # Second run: chunk 1 is skipped (hash match), but x must be restored
  # so chunk 2 (y <- x + 1) can succeed
  log2 <- file.path(tempdir(), "bridge2.log")
  on.exit(unlink(log2), add = TRUE)
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log2
  ))

  registry2 <- registry_read(reg)
  expect_equal(registry2[["bridge:1"]]$status, "ok")
  expect_equal(registry2[["bridge:2"]]$status, "ok")
})

# Test B: snapshot only captures new variables, not pre-existing ones
test_that("snapshot only captures new variables, not pre-existing ones", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  log_path <- tempfile("log_")
  img_dir <- tempfile("images_")
  on.exit(unlink(c(reg_path, log_path)), add = TRUE)
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  state <- new_run_state(
    registry_file = reg_path,
    log_file = log_path,
    image_dir = img_dir,
    n_chapters = 1L
  )
  on.exit(close_run_state(state), add = TRUE)

  env <- new.env(parent = globalenv())
  env$pre_existing <- "should not be snapshotted"

  suppressMessages(run_chunk(
    state = state,
    chapter_name = "snap", chunk_i = 1L, n_chunks = 1L,
    start_line = 1L, end_line = 2L,
    label = "chunk_1", hash = "abc", eval = FALSE,
    env = env,
    code = "new_var <- 99"
  ))

  snap_dir <- file.path(dirname(reg_path), ".snapshots", "snap:1")
  snap_files <- list.files(snap_dir, pattern = "\\.rds$")
  expect_true("new_var.rds" %in% snap_files)
  expect_false("pre_existing.rds" %in% snap_files)
})

# Test C: large objects are not snapshotted (size guard)
test_that("large objects are not snapshotted", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  log_path <- tempfile("log_")
  img_dir <- tempfile("images_")
  on.exit(unlink(c(reg_path, log_path)), add = TRUE)
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  state <- new_run_state(
    registry_file = reg_path,
    log_file = log_path,
    image_dir = img_dir,
    n_chapters = 1L
  )
  on.exit(close_run_state(state), add = TRUE)

  # Use a very small max_bytes to trigger the guard
  state$snapshot_max_bytes <- 100

  suppressMessages(run_chunk(
    state = state,
    chapter_name = "big", chunk_i = 1L, n_chunks = 1L,
    start_line = 1L, end_line = 2L,
    label = "chunk_1", hash = "abc", eval = FALSE,
    env = new.env(parent = globalenv()),
    code = "big_obj <- rep('x', 1000)"
  ))

  snap_dir <- file.path(dirname(reg_path), ".snapshots", "big:1")
  snap_files <- list.files(snap_dir, pattern = "\\.rds$")
  expect_length(snap_files, 0L)
})

# Test D: snapshot is invalidated when chunk hash changes
test_that("snapshot is invalidated when chunk hash changes", {
  book_dir <- file.path(tempdir(), "hash_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)

  writeLines(c(
    "project:", "  type: book", "book:", "  chapters:",
    "    - hash.qmd"
  ), file.path(book_dir, "_quarto.yml"))

  writeLines(c(
    "---", "title: Hash", "---", "",
    "```{r}", "#| eval: false", "x <- 10", "```",
    "", "```{r}", "y <- x", "```"
  ), file.path(book_dir, "hash.qmd"))

  reg <- file.path(tempdir(), "hash_registry.yaml")
  log1 <- file.path(tempdir(), "hash1.log")
  on.exit(unlink(c(reg, log1)), add = TRUE)

  # First run
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log1
  ))

  # Now edit the chunk (changes hash)
  writeLines(c(
    "---", "title: Hash", "---", "",
    "```{r}", "#| eval: false", "x <- 20", "```",
    "", "```{r}", "y <- x", "```"
  ), file.path(book_dir, "hash.qmd"))

  # Second run: chunk 1 re-runs (hash changed), snapshot is regenerated
  log2 <- file.path(tempdir(), "hash2.log")
  on.exit(unlink(log2), add = TRUE)
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log2
  ))

  # Third run: chunk 1 is now skipped, x should be restored with value 20
  log3 <- file.path(tempdir(), "hash3.log")
  on.exit(unlink(log3), add = TRUE)
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log3
  ))

  snap_dir <- file.path(dirname(reg), ".snapshots", "hash:1")
  expect_equal(readRDS(file.path(snap_dir, "x.rds")), 20)
})

# Test E: eval:true chunks are never snapshotted
test_that("eval:true chunks are never snapshotted", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  log_path <- tempfile("log_")
  img_dir <- tempfile("images_")
  on.exit(unlink(c(reg_path, log_path)), add = TRUE)
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  state <- new_run_state(
    registry_file = reg_path,
    log_file = log_path,
    image_dir = img_dir,
    n_chapters = 1L
  )
  on.exit(close_run_state(state), add = TRUE)

  suppressMessages(run_chunk(
    state = state,
    chapter_name = "nosnap", chunk_i = 1L, n_chunks = 1L,
    start_line = 1L, end_line = 2L,
    label = "chunk_1", hash = "abc", eval = TRUE,
    env = new.env(parent = globalenv()),
    code = "z <- 42"
  ))

  snap_dir <- file.path(dirname(reg_path), ".snapshots", "nosnap:1")
  expect_false(dir.exists(snap_dir))
})

# Test F: dc_merge pattern (eval:false defines var, eval:true displays it)
test_that("dc_merge pattern works across skip", {
  book_dir <- file.path(tempdir(), "dcmerge_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)

  writeLines(c(
    "project:", "  type: book", "book:", "  chapters:",
    "    - merge.qmd"
  ), file.path(book_dir, "_quarto.yml"))

  # Mimics dc_merge: setup (eval:true), define cube (eval:false),
  # display timeline (eval:true)
  writeLines(c(
    "---", "title: Merge", "---", "",
    "```{r}",
    "library(tibble)",
    "```",
    "",
    "```{r}",
    "#| eval: false",
    "cube_a <- list(timeline = 1:10, name = 'S2')",
    "cube_b <- list(timeline = 1:5, name = 'L8')",
    "```",
    "",
    "```{r}",
    "length(cube_a$timeline)",
    "```",
    "",
    "```{r}",
    "cube_b$name",
    "```"
  ), file.path(book_dir, "merge.qmd"))

  reg <- file.path(tempdir(), "dcmerge_registry.yaml")
  log1 <- file.path(tempdir(), "dcmerge1.log")
  on.exit(unlink(c(reg, log1)), add = TRUE)

  # First run: all chunks execute
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log1
  ))

  registry1 <- registry_read(reg)
  expect_true(all(vapply(registry1, function(x) x$status, "") == "ok"))

  # Second run: chunk 2 (eval:false) is skipped, but cube_a and cube_b
  # must be available for chunks 3 and 4
  log2 <- file.path(tempdir(), "dcmerge2.log")
  on.exit(unlink(log2), add = TRUE)
  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE, log_file = log2
  ))

  registry2 <- registry_read(reg)
  expect_true(all(vapply(registry2, function(x) x$status, "") == "ok"))
})
