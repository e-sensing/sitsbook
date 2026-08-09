create_plot_book <- function(dir) {
  writeLines(c(
    "project:",
    "  type: book",
    "book:",
    "  chapters:",
    "    - plots.qmd"
  ), file.path(dir, "_quarto.yml"))

  writeLines(c(
    "---",
    "title: Plots",
    "---",
    "",
    "# Base graphics",
    "",
    "```{r}",
    "#| label: fig-base",
    "plot(1:10)",
    "```",
    "",
    "# Deferred render (e.g. tmap-style objects)",
    "",
    "```{r}",
    "#| eval: false",
    "#| label: fig-deferred",
    "make_deferred <- function() structure(list(), class = 'deferred_plot')",
    "print.deferred_plot <- function(x, ...) plot(1:3, 4:6)",
    "make_deferred()",
    "```",
    "",
    "# No plot here",
    "",
    "```{r}",
    "z <- 1 + 1",
    "```"
  ), file.path(dir, "plots.qmd"))
}

test_that("run_chunk saves base-graphics plots as normalized PNG files", {
  book_dir <- file.path(tempdir(), "plot_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_plot_book(book_dir)

  reg <- file.path(tempdir(), "plot_registry.yaml")
  img_dir <- file.path(tempdir(), "plot_images")
  log <- file.path(tempdir(), "plot.log")
  on.exit(unlink(c(reg, log)), add = TRUE)
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  suppressMessages(generate_book_data(
    book_dir, registry = reg, python_sync = FALSE,
    image_dir = img_dir, log_file = log
  ))

  saved <- list.files(file.path(img_dir, "plots"), full.names = TRUE)
  expect_true(length(saved) >= 2L)
  expect_true(any(grepl("fig-base", saved)))
  expect_true(any(grepl("fig-deferred", saved)))
  # The third chunk has no plot output, so it must not create a spurious file
  expect_false(any(grepl("chunk_3", saved)))

  registry <- registry_read(reg)
  expect_true(length(registry[["plots:1"]]$images) > 0L)
  expect_true(length(registry[["plots:2"]]$images) > 0L)

  with_images <- list_chunks_with_images(registry)
  expect_true(all(c("plots:1", "plots:2") %in% paste0(with_images$chapter, ":", with_images$chunk)))
  expect_false(any(with_images$chunk == 3L))
})

test_that("run_chunk with no plots does not create an image directory entry", {
  reg_path <- tempfile("registry_", fileext = ".yaml")
  on.exit(unlink(reg_path), add = TRUE)
  img_dir <- file.path(tempdir(), "no_plot_images")
  on.exit(unlink(img_dir, recursive = TRUE), add = TRUE)

  log_path <- tempfile("log_")
  on.exit(unlink(log_path), add = TRUE)

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

  suppressMessages(run_chunk(
    state = state,
    chapter_name = "noplot",
    chunk_i = 1L,
    n_chunks = 1L,
    start_line = 1L,
    end_line = 2L,
    label = "chunk_1",
    hash = "xyz",
    eval = TRUE,
    env = new.env(),
    code = "1 + 1"
  ))

  expect_false(dir.exists(file.path(img_dir, "noplot")))
})
