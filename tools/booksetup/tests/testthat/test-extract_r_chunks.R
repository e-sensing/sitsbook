test_that("extract_r_chunks extracts only R chunks", {
  qmd <- system.file("extdata", "sample.qmd", package = "booksetup")
  chunks <- extract_r_chunks(qmd)

  expect_length(chunks, 3L)
  expect_named(chunks, c("chunk_1", "chunk_2", "chunk_3"))
})

test_that("chunk option lines are stripped", {
  qmd <- system.file("extdata", "sample.qmd", package = "booksetup")
  chunks <- extract_r_chunks(qmd)

  all_code <- unlist(chunks, use.names = FALSE)
  expect_false(any(grepl("^#\\|", all_code)))
})

test_that("eval: false code is preserved", {
  qmd <- system.file("extdata", "sample.qmd", package = "booksetup")
  chunks <- extract_r_chunks(qmd)

  all_code <- paste(unlist(chunks, use.names = FALSE), collapse = "\n")
  expect_true(grepl("sits_cube\\(", all_code))
  expect_true(grepl("sits_regularize\\(", all_code))
})

test_that("python chunks are ignored", {
  qmd <- system.file("extdata", "sample.qmd", package = "booksetup")
  chunks <- extract_r_chunks(qmd)

  all_code <- paste(unlist(chunks, use.names = FALSE), collapse = "\n")
  expect_false(grepl("pysits", all_code))
})

test_that("chunks carry source line-number attributes", {
  qmd <- system.file("extdata", "sample.qmd", package = "booksetup")
  chunks <- extract_r_chunks(qmd)

  for (i in seq_along(chunks)) {
    expect_type(attr(chunks[[i]], "start_line"), "integer")
    expect_type(attr(chunks[[i]], "end_line"), "integer")
    expect_gt(attr(chunks[[i]], "end_line"), attr(chunks[[i]], "start_line"))
  }
})

test_that("chunk headers with trailing whitespace are recognized", {
  qmd <- tempfile(fileext = ".qmd")
  writeLines(c("```{r} ", "1 + 1", "```"), qmd)
  on.exit(unlink(qmd), add = TRUE)

  chunks <- extract_r_chunks(qmd)
  expect_length(chunks, 1L)
})

test_that("trailing whitespace in header does not produce a false label", {
  qmd <- tempfile(fileext = ".qmd")
  writeLines(c("```{r} ", "1 + 1", "```"), qmd)
  on.exit(unlink(qmd), add = TRUE)

  chunks <- extract_r_chunks(qmd)
  expect_named(chunks, "chunk_1")
})

test_that("eval attribute defaults to TRUE", {
  qmd <- tempfile(fileext = ".qmd")
  writeLines(c("```{r}", "x <- 1", "```"), qmd)
  on.exit(unlink(qmd), add = TRUE)

  chunks <- extract_r_chunks(qmd)
  expect_true(attr(chunks[[1]], "eval"))
})

test_that("eval attribute is captured from #| eval: false", {
  qmd <- tempfile(fileext = ".qmd")
  writeLines(c("```{r}", "#| eval: false", "x <- 1", "```"), qmd)
  on.exit(unlink(qmd), add = TRUE)

  chunks <- extract_r_chunks(qmd)
  expect_false(attr(chunks[[1]], "eval"))
})

test_that("eval attribute is captured from #| eval: true", {
  qmd <- tempfile(fileext = ".qmd")
  writeLines(c("```{r}", "#| eval: true", "x <- 1", "```"), qmd)
  on.exit(unlink(qmd), add = TRUE)

  chunks <- extract_r_chunks(qmd)
  expect_true(attr(chunks[[1]], "eval"))
})
