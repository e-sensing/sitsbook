test_that("has_chapter_data reports empty/non-existent dirs", {
  tmp <- tempdir()
  expect_false(has_chapter_data("not_there", tempdir = tmp))

  dir.create(file.path(tmp, "empty_chapter"), showWarnings = FALSE)
  expect_false(has_chapter_data("empty_chapter", tempdir = tmp))
})

test_that("has_chapter_data reports non-empty dirs", {
  tmp <- tempdir()
  dir.create(file.path(tmp, "has_data"), showWarnings = FALSE)
  writeLines("x", file.path(tmp, "has_data", "file.txt"))
  expect_true(has_chapter_data("has_data", tempdir = tmp))
})
