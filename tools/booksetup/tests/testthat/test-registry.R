test_that("chunk_hash is stable and sensitive to code changes", {
  h1 <- chunk_hash(c("x <- 1", "y <- 2"))
  h2 <- chunk_hash(c("x <- 1", "y <- 2"))
  h3 <- chunk_hash(c("x <- 1", "y <- 3"))

  expect_type(h1, "character")
  expect_length(h1, 1L)
  expect_identical(h1, h2)
  expect_false(identical(h1, h3))
})

test_that("registry_read returns empty list when file is missing", {
  expect_identical(registry_read(tempfile()), list())
})

test_that("registry round-trips through yaml", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)

  reg <- list(
    "intro_visualisation:1" = list(
      hash = "abc123",
      elapsed = 12.3,
      lines = "12-20",
      label = "chunk_1"
    )
  )

  registry_write(path, reg)
  expect_true(file.exists(path))

  back <- registry_read(path)
  expect_identical(back, reg)
})

test_that("registry_path returns expected default", {
  expect_equal(
    registry_path("/tmp/book"),
    "/tmp/book/.booksetup_registry.yaml"
  )
})

test_that("chunk_report sorts by elapsed descending", {
  reg <- list(
    "a:1" = list(elapsed = 1, lines = "1-2", label = "x", hash = "h1"),
    "b:2" = list(elapsed = 10, lines = "3-4", label = "y", hash = "h2"),
    "c:3" = list(elapsed = 5, lines = "5-6", label = "z", hash = "h3")
  )
  df <- chunk_report(reg, n = 10L)
  expect_equal(df$chapter, c("b", "c", "a"))
  expect_equal(df$chunk, c(2L, 3L, 1L))
})

test_that("chunk_report handles empty registry", {
  df <- chunk_report(list())
  expect_equal(nrow(df), 0L)
  expect_named(df, c("chapter", "chunk", "lines", "label", "elapsed", "hash"))
})

sample_clear_registry <- function() {
  list(
    "dc_merge:1" = list(status = "ok", hash = "h1"),
    "dc_merge:2" = list(status = "ok", hash = "h2"),
    "dc_merge:7" = list(status = "ok", hash = "h7"),
    "dc_regularize:1" = list(status = "ok", hash = "h1r")
  )
}

test_that("registry_clear removes specific chunks in one chapter", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)
  registry_write(path, sample_clear_registry())

  cleared <- suppressMessages(registry_clear("dc_merge", chunk = c(2, 7), registry = path))
  expect_setequal(cleared, c("dc_merge:2", "dc_merge:7"))

  reg <- registry_read(path)
  expect_named(reg, c("dc_merge:1", "dc_regularize:1"))
})

test_that("registry_clear removes all chunks of a chapter when chunk = NULL", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)
  registry_write(path, sample_clear_registry())

  cleared <- suppressMessages(registry_clear("dc_merge", registry = path))
  expect_setequal(cleared, c("dc_merge:1", "dc_merge:2", "dc_merge:7"))

  reg <- registry_read(path)
  expect_named(reg, "dc_regularize:1")
})

test_that("registry_clear supports clearing multiple whole chapters", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)
  registry_write(path, sample_clear_registry())

  cleared <- suppressMessages(
    registry_clear(c("dc_merge", "dc_regularize"), registry = path)
  )
  expect_length(cleared, 4L)

  reg <- registry_read(path)
  expect_length(reg, 0L)
})

test_that("registry_clear errors when chunk is given with multiple chapters", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)
  registry_write(path, sample_clear_registry())

  expect_error(
    registry_clear(c("dc_merge", "dc_regularize"), chunk = 1),
    "single chapter name"
  )
})

test_that("registry_clear messages and returns character(0) when nothing matches", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)
  registry_write(path, sample_clear_registry())

  expect_message(
    cleared <- registry_clear("not_a_chapter", registry = path),
    "No matching registry entries"
  )
  expect_identical(cleared, character())

  # registry is untouched
  expect_length(registry_read(path), 4L)
})
