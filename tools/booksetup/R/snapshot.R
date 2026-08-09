# Chunk environment snapshot/restore.
#
# When an eval:false chunk completes successfully, we snapshot the new
# variables it created. When that chunk is later skipped (hash match),
# we restore those variables into the chapter environment so that
# downstream eval:true chunks can use them.

#' Snapshot new variables from a chunk environment
#'
#' Compares the current variables in `env` against `pre_vars` (captured
#' before the chunk ran) and saves each new variable as an `.rds` file
#' under `snapshot_dir/<key>/`.
#'
#' @param key Registry key (e.g. `"dc_merge:2"`).
#' @param env The chunk's evaluation environment.
#' @param pre_vars Character vector of variable names that existed before
#'   the chunk ran.
#' @param snapshot_dir Base directory for snapshots.
#' @param max_bytes Maximum object size (in bytes) to snapshot. Objects
#'   larger than this are skipped with a message.
#'
#' @return Character vector of saved variable names, invisibly.
#' @keywords internal
snapshot_chunk_env <- function(key, env, pre_vars, snapshot_dir,
                               max_bytes = 50e6) {
  new_vars <- setdiff(ls(env, all.names = FALSE), pre_vars)
  if (length(new_vars) == 0L) return(invisible(character()))

  snap_dir <- file.path(snapshot_dir, key)
  dir.create(snap_dir, recursive = TRUE, showWarnings = FALSE)

  # Remove old snapshots for this key (in case the set of variables changed)
  old_files <- list.files(snap_dir, full.names = TRUE)
  if (length(old_files) > 0L) file.remove(old_files)

  saved <- character()
  for (v in new_vars) {
    obj <- get(v, envir = env)
    size <- as.numeric(object.size(obj))
    if (size > max_bytes) {
      message(sprintf("  [snapshot] skipping %s (%.1f MB > %.0f MB limit)",
                      v, size / 1e6, max_bytes / 1e6))
      next
    }
    path <- file.path(snap_dir, paste0(v, ".rds"))
    saveRDS(obj, path)
    saved <- c(saved, v)
  }
  invisible(saved)
}

#' Restore snapshotted variables into a chunk environment
#'
#' Loads all `.rds` files from `snapshot_dir/<key>/` and assigns them
#' into `env`.
#'
#' @param key Registry key (e.g. `"dc_merge:2"`).
#' @param env The chapter's evaluation environment.
#' @param snapshot_dir Base directory for snapshots.
#'
#' @return `TRUE` if variables were restored, `FALSE` otherwise, invisibly.
#' @keywords internal
restore_chunk_env <- function(key, env, snapshot_dir) {
  snap_dir <- file.path(snapshot_dir, key)
  if (!dir.exists(snap_dir)) return(invisible(FALSE))

  files <- list.files(snap_dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) == 0L) return(invisible(FALSE))

  for (f in files) {
    var_name <- sub("\\.rds$", "", basename(f))
    assign(var_name, readRDS(f), envir = env)
  }
  invisible(TRUE)
}

# ---- diagnostics ----

#' Per-chunk snapshot diagnostics
#'
#' Reports, for every chunk in `registry`, whether it has an associated
#' snapshot under `snapshot_dir`, how many variables it holds, and their
#' total size on disk. `eval: true` chunks and chunks whose last run
#' errored are never snapshotted (see [snapshot_chunk_env()]) and are
#' reported as `"not_applicable"`.
#'
#' `status` values:
#' - `"not_applicable"`: chunk is `eval: true`, or its last run errored
#'   (snapshotting does not apply).
#' - `"missing"`: `eval: false` chunk completed `"ok"` but has no
#'   snapshot directory at all. This is expected (not a problem) for
#'   chunks that define no new variables (e.g. side-effect-only chunks
#'   that just write files to disk) -- it is a *signal* to investigate,
#'   not necessarily a bug: check whether the chunk was expected to
#'   define a bridge variable that a downstream chunk consumes.
#' - `"empty"`: the snapshot directory exists but contains no `.rds`
#'   files (e.g. every candidate variable exceeded the size guard).
#' - `"ok"`: at least one variable was snapshotted.
#'
#' @param registry A registry list, as returned by [registry_read()].
#' @param snapshot_dir Base directory for snapshots (`state$snapshot_dir`
#'   from [new_run_state()], typically `<tempdir>/.snapshots`).
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `key`,
#'   `n_vars`, `size_bytes`, `status`.
#' @export
snapshot_info <- function(registry, snapshot_dir) {
  df <- registry_to_df(registry)
  if (nrow(df) == 0L) {
    return(data.frame(
      chapter = character(), chunk = integer(), key = character(),
      n_vars = integer(), size_bytes = numeric(), status = character(),
      stringsAsFactors = FALSE
    ))
  }

  key <- paste0(df$chapter, ":", df$chunk)
  applicable <- !is.na(df$eval) & !df$eval & df$status != "error"

  n_vars <- integer(nrow(df))
  size_bytes <- numeric(nrow(df))
  status <- rep("not_applicable", nrow(df))

  for (i in which(applicable)) {
    snap_dir <- file.path(snapshot_dir, key[i])
    if (!dir.exists(snap_dir)) {
      status[i] <- "missing"
      next
    }
    files <- list.files(snap_dir, pattern = "\\.rds$", full.names = TRUE)
    if (length(files) == 0L) {
      status[i] <- "empty"
      next
    }
    n_vars[i] <- length(files)
    size_bytes[i] <- sum(file.size(files))
    status[i] <- "ok"
  }

  out <- data.frame(
    chapter = df$chapter,
    chunk = df$chunk,
    key = key,
    n_vars = n_vars,
    size_bytes = size_bytes,
    status = status,
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

#' Write the snapshot diagnostics to a CSV file
#'
#' @param registry A registry list, as returned by [registry_read()].
#' @param snapshot_dir Base directory for snapshots.
#' @param path Output CSV path.
#'
#' @return `path`, invisibly.
#' @export
write_snapshot_summary <- function(registry, snapshot_dir, path) {
  df <- snapshot_info(registry, snapshot_dir)
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}
