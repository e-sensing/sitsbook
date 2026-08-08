sample_registry <- function() {
  list(
    "a:1" = list(status = "ok", hash = "h1", elapsed = 1, lines = "1-2",
                 label = "x", eval = TRUE, images = character(0)),
    "a:2" = list(status = "ok", hash = "h2", elapsed = 20, lines = "3-4",
                 label = "y", eval = FALSE, images = c("a/img1.png")),
    "b:1" = list(status = "ok", hash = "h3", elapsed = 10, lines = "5-6",
                 label = "z", eval = TRUE, images = c("b/img1.png", "b/img2.png")),
    "b:2" = list(status = "error", hash = "h4", elapsed = 0.5, lines = "7-8",
                 label = "w", eval = TRUE, error = "boom",
                 timestamp = "2026-01-01T00:00:00.000")
  )
}

test_that("registry_to_df builds a full data frame tolerant of legacy entries", {
  reg <- list(
    "legacy:1" = list(hash = "h0", elapsed = 5, lines = "1-2", label = "l")
  )
  df <- registry_to_df(reg)
  expect_equal(df$status, "ok")
  expect_equal(df$n_images, 0L)
  expect_true(is.na(df$eval))
  expect_equal(df$error, "")
})

test_that("registry_to_df handles an empty registry", {
  df <- registry_to_df(list())
  expect_equal(nrow(df), 0L)
  expect_named(df, c("chapter", "chunk", "lines", "label", "eval", "status",
                      "elapsed", "hash", "n_images", "images", "error", "timestamp"))
})

test_that("chunk_report excludes errored chunks", {
  df <- chunk_report(sample_registry(), n = 10L)
  expect_false("b:2" %in% paste0(df$chapter, ":", df$chunk))
  expect_equal(df$chapter[1L], "a")
  expect_equal(df$chunk[1L], 2L)
})

test_that("chunk_report still sorts by elapsed descending (legacy entries, no status field)", {
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

test_that("list_failed_chunks returns only error entries", {
  df <- list_failed_chunks(sample_registry())
  expect_equal(nrow(df), 1L)
  expect_equal(df$chapter, "b")
  expect_equal(df$chunk, 2L)
  expect_equal(df$error, "boom")
})

test_that("list_slow_chunks defaults to eval: true chunks sorted by elapsed", {
  df <- list_slow_chunks(sample_registry())
  expect_true(all(df$eval))
  expect_equal(df$chapter, c("b", "a"))
  expect_equal(df$chunk, c(1L, 1L))
})

test_that("list_slow_chunks(eval_only = FALSE) returns only eval: false chunks", {
  df <- list_slow_chunks(sample_registry(), eval_only = FALSE)
  expect_equal(nrow(df), 1L)
  expect_equal(df$chapter, "a")
  expect_equal(df$chunk, 2L)
})

test_that("list_slow_chunks(eval_only = NULL) returns all completed chunks", {
  df <- list_slow_chunks(sample_registry(), eval_only = NULL)
  expect_equal(nrow(df), 3L)
})

test_that("list_slow_chunks respects n", {
  df <- list_slow_chunks(sample_registry(), eval_only = NULL, n = 1L)
  expect_equal(nrow(df), 1L)
  expect_equal(df$elapsed, 20)
})

test_that("list_chunks_with_images returns only chunks with images, sorted by elapsed", {
  df <- list_chunks_with_images(sample_registry())
  expect_equal(nrow(df), 2L)
  # a:2 has elapsed = 20, b:1 has elapsed = 10, so a:2 sorts first.
  expect_equal(df$chapter, c("a", "b"))
  expect_equal(df$n_images, c(1L, 2L))
  expect_match(df$images[df$chapter == "b"], "img1.png; .*img2.png")
})

test_that("chunk_summary_df is equivalent to registry_to_df", {
  expect_equal(chunk_summary_df(sample_registry()), registry_to_df(sample_registry()))
})

test_that("write_chunk_summary writes a CSV with the expected columns", {
  out <- tempfile(fileext = ".csv")
  on.exit(unlink(out), add = TRUE)

  write_chunk_summary(sample_registry(), out)
  expect_true(file.exists(out))

  df <- utils::read.csv(out, stringsAsFactors = FALSE)
  expect_named(df, c("chapter", "chunk", "lines", "label", "eval", "status",
                      "elapsed", "hash", "n_images", "images", "error", "timestamp"))
  expect_equal(nrow(df), 4L)
})

test_that("read_event_log returns an empty list when the file doesn't exist", {
  expect_identical(read_event_log(tempfile()), list())
})

test_that("event_log_to_df flattens heterogeneous event records", {
  events <- list(
    list(event = "run_start", time = "t1", n_chapters = 2),
    list(event = "chunk_error", time = "t2", chapter = "a", chunk = 1, message = "boom")
  )
  df <- event_log_to_df(events)
  expect_equal(nrow(df), 2L)
  expect_true(all(c("event", "time", "n_chapters", "chapter", "chunk", "message") %in% names(df)))
  expect_true(is.na(df$chapter[1L]))
  expect_equal(df$message[2L], "boom")
})

# Fixture covering the three intervention criteria at once: chunks that
# errored, eval:true chunks above an elapsed threshold, eval:true chunks
# below the threshold (should be excluded), and an eval:false chunk that's
# slow but must be excluded from the eval:true-only view.
intervention_registry <- function() {
  list(
    "dc_ardcollections:34" = list(
      status = "error", hash = "he", elapsed = 2.1, lines = "953-971",
      label = "chunk_34", eval = TRUE, error = "invalid input - data frame without content",
      timestamp = "2026-08-08T10:00:00.000"
    ),
    "ts_som:6" = list(
      status = "ok", hash = "h1", elapsed = 7299.7, lines = "126-139",
      label = "chunk_6", eval = TRUE, images = character(0)
    ),
    "ts_som:12" = list(
      status = "ok", hash = "h2", elapsed = 4312.8, lines = "318-340",
      label = "chunk_12", eval = TRUE, images = character(0)
    ),
    "intro_quicktour:2" = list(
      status = "ok", hash = "h3", elapsed = 5.0, lines = "56-64",
      label = "chunk_2", eval = TRUE, images = character(0)
    ),
    "dc_regularize:3" = list(
      status = "ok", hash = "h4", elapsed = 9000.0, lines = "70-90",
      label = "chunk_3", eval = FALSE, images = character(0)
    )
  )
}

test_that("list_failed_chunks + list_slow_chunks(threshold) identify intervention candidates", {
  reg <- intervention_registry()
  threshold <- 60 # seconds

  failed <- list_failed_chunks(reg)
  expect_equal(nrow(failed), 1L)
  expect_equal(paste0(failed$chapter, ":", failed$chunk), "dc_ardcollections:34")

  slow_eval_true <- list_slow_chunks(reg, eval_only = TRUE, n = Inf)
  slow_eval_true <- slow_eval_true[slow_eval_true$elapsed > threshold, , drop = FALSE]

  # eval:false ts_som chunks pass the threshold and are eval:true -> included.
  # intro_quicktour:2 is eval:true but below the threshold -> excluded.
  # dc_regularize:3 is slow but eval:false -> excluded.
  expect_equal(nrow(slow_eval_true), 2L)
  expect_setequal(paste0(slow_eval_true$chapter, ":", slow_eval_true$chunk),
                   c("ts_som:6", "ts_som:12"))
  expect_true(all(slow_eval_true$eval))
  expect_true(all(slow_eval_true$elapsed > threshold))

  # Combined "needs intervention" view: errored OR eval:true-and-slow.
  df <- chunk_summary_df(reg)
  flagged <- df[df$status == "error" |
                  (!is.na(df$eval) & df$eval & df$elapsed > threshold), , drop = FALSE]
  expect_setequal(paste0(flagged$chapter, ":", flagged$chunk),
                   c("dc_ardcollections:34", "ts_som:6", "ts_som:12"))
})
