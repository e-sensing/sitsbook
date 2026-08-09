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
