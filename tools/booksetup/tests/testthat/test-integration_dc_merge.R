# Integration test: reproduces the exact bridge shape used by dc_merge.qmd
# (see /home/rolf/gh/sitsbook/dc_merge.qmd, "Merging HLS Landsat and
# Sentinel-2 collections" section) without hitting any live STAC/MPC/HLS
# endpoints. Real `sits` cube objects are S3 lists/tibbles with no active
# bindings or external pointers, so a plain-list stand-in with the same
# shape (a `timeline` field, `merge()`-like combination, and a
# `cube_copy()`-like derived object) is representative for exercising
# snapshot/restore.
#
# Mirrors the actual chapter structure:
#   chunk 1 (eval:true)  - setup/library-equivalent
#   chunk 2 (eval:false) - defines hls_cube_s2, hls_cube_l8, hls_cube_merged
#                          (the "bridge" chunk being retired in dc_merge.qmd)
#   chunk 3 (eval:true)  - "timeline" of hls_cube_s2
#   chunk 4 (eval:true)  - "timeline" of hls_cube_l8
#   chunk 5 (eval:true)  - "timeline" of hls_cube_merged
#   chunk 6 (eval:false) - a second, chained bridge chunk: cube_hls_local,
#                          derived from hls_cube_merged (as sits_cube_copy()
#                          derives from hls_cube_merged in the real chapter)
#   chunk 7 (eval:true)  - consumes cube_hls_local

create_dc_merge_sim_book <- function(dir) {
  writeLines(c(
    "project:",
    "  type: book",
    "book:",
    "  chapters:",
    "    - dc_merge_sim.qmd"
  ), file.path(dir, "_quarto.yml"))

  writeLines(c(
    "---",
    "title: DC Merge Simulation",
    "---",
    "",
    "```{r}",
    "# setup (stand-in for library(sits); library(sitsdata))",
    "sits_timeline <- function(cube) cube$timeline",
    "sits_merge_sim <- function(a, b) {",
    "  list(timeline = sort(union(a$timeline, b$timeline)),",
    "       name = paste(a$name, b$name, sep = '+'))",
    "}",
    "sits_cube_copy_sim <- function(cube) {",
    "  list(timeline = cube$timeline, name = paste0(cube$name, '_local'))",
    "}",
    "```",
    "",
    "```{r}",
    "#| eval: false",
    "# stand-in for two sits_cube() calls + sits_merge()",
    "hls_cube_s2 <- list(timeline = as.Date('2020-06-01') + (0:5) * 5,",
    "                     name = 'HLSS30')",
    "hls_cube_l8 <- list(timeline = as.Date('2020-06-03') + (0:4) * 8,",
    "                     name = 'HLSL30')",
    "hls_cube_merged <- sits_merge_sim(hls_cube_s2, hls_cube_l8)",
    "```",
    "",
    "```{r}",
    "# Timeline of the Sentinel-2 cube",
    "length(sits_timeline(hls_cube_s2))",
    "```",
    "",
    "```{r}",
    "# Timeline of the Landsat-8 cube",
    "length(sits_timeline(hls_cube_l8))",
    "```",
    "",
    "```{r}",
    "# Timeline of the merged cube",
    "length(sits_timeline(hls_cube_merged))",
    "```",
    "",
    "```{r}",
    "#| eval: false",
    "# stand-in for sits_cube_copy(cube = hls_cube_merged, ...): a second,",
    "# chained bridge chunk that itself depends on a restored variable",
    "cube_hls_local <- sits_cube_copy_sim(hls_cube_merged)",
    "```",
    "",
    "```{r}",
    "# consumes the chained bridge output",
    "cube_hls_local$name",
    "```"
  ), file.path(dir, "dc_merge_sim.qmd"))
}

test_that("dc_merge bridge shape survives skip-and-restore across chained bridge chunks", {
  book_dir <- file.path(tempdir(), "dc_merge_sim_book")
  dir.create(book_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(book_dir, recursive = TRUE), add = TRUE)
  create_dc_merge_sim_book(book_dir)

  reg <- file.path(tempdir(), "dc_merge_sim_registry.yaml")
  on.exit(unlink(reg), add = TRUE)

  run_and_check <- function(log_file) {
    suppressMessages(generate_book_data(
      book_dir, registry = reg, python_sync = FALSE, log_file = log_file
    ))
    registry <- registry_read(reg)
    expect_true(all(vapply(registry, function(x) x$status, "") == "ok"))
    registry
  }

  # Run 1: everything computes fresh.
  log1 <- file.path(tempdir(), "dc_merge_sim1.log")
  on.exit(unlink(log1), add = TRUE)
  registry1 <- run_and_check(log1)
  expect_length(registry1, 7L)

  # Run 2: both eval:false chunks (2 and 6) are skipped; restore must supply
  # hls_cube_s2/hls_cube_l8/hls_cube_merged (chunk 2) AND cube_hls_local
  # (chunk 6, itself derived from a restored variable) so chunks 3-5 and 7
  # still succeed.
  log2 <- file.path(tempdir(), "dc_merge_sim2.log")
  on.exit(unlink(log2), add = TRUE)
  events2 <- {
    registry2 <- run_and_check(log2)
    read_event_log(log2)
  }
  event_types <- vapply(events2, function(e) e$event %||% "", character(1L))
  expect_true("chunk_skip" %in% event_types)

  # Run 3: idempotent - same result again.
  log3 <- file.path(tempdir(), "dc_merge_sim3.log")
  on.exit(unlink(log3), add = TRUE)
  run_and_check(log3)

  # Snapshots exist for both bridge chunks.
  snap_dir <- file.path(dirname(reg), ".snapshots")
  expect_true(dir.exists(file.path(snap_dir, "dc_merge_sim:2")))
  expect_true(dir.exists(file.path(snap_dir, "dc_merge_sim:6")))
  expect_true(file.exists(file.path(snap_dir, "dc_merge_sim:2", "hls_cube_s2.rds")))
  expect_true(file.exists(file.path(snap_dir, "dc_merge_sim:2", "hls_cube_l8.rds")))
  expect_true(file.exists(file.path(snap_dir, "dc_merge_sim:2", "hls_cube_merged.rds")))
  expect_true(file.exists(file.path(snap_dir, "dc_merge_sim:6", "cube_hls_local.rds")))

  # Restored values are correct, not just present.
  restored_merged <- readRDS(file.path(snap_dir, "dc_merge_sim:2", "hls_cube_merged.rds"))
  expect_equal(restored_merged$name, "HLSS30+HLSL30")
  restored_local <- readRDS(file.path(snap_dir, "dc_merge_sim:6", "cube_hls_local.rds"))
  expect_equal(restored_local$name, "HLSS30+HLSL30_local")
})
