test_that("chapter_files returns qmds in book order including part pages", {
  book_dir <- system.file("extdata", package = "booksetup")
  files <- chapter_files(book_dir)

  expect_length(files, 3L)
  expect_equal(basename(files), c("sample.qmd", "section.qmd", "other.qmd"))
})

test_that("chapter_files errors when _quarto.yml is missing", {
  expect_error(chapter_files(tempdir()), "No _quarto.yml found")
})
