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
