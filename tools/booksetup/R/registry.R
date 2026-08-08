#' Default path for the chunk completion registry
#'
#' @param tempdir Root temporary directory used by the book. Defaults to
#'   `~/sitsbook/tempdir`.
#'
#' @return A file path.
#' @export
registry_path <- function(tempdir = path.expand("~/sitsbook/tempdir")) {
  file.path(tempdir, ".booksetup_registry.yaml")
}

#' Compute a stable hash for a chunk's code
#'
#' @param code Character vector of R code lines.
#'
#' @return A 32-character MD5 hex string.
#' @export
chunk_hash <- function(code) {
  tf <- tempfile("chunk_")
  on.exit(unlink(tf), add = TRUE)
  writeLines(code, tf)
  unname(tools::md5sum(tf))
}

#' Read the chunk completion registry
#'
#' @param path Path to the YAML registry file.
#'
#' @return A named list; an empty list if the file does not exist.
#' @export
registry_read <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  yaml::read_yaml(path)
}

#' Write the chunk completion registry
#'
#' @param path Path to the YAML registry file.
#' @param registry Named list of chunk entries.
#'
#' @return `path`, invisibly.
#' @export
registry_write <- function(path, registry) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  yaml::write_yaml(registry, path)
  invisible(path)
}

#' Build the registry key for a chunk
#'
#' @param chapter Chapter name.
#' @param index Chunk index within the chapter.
#'
#' @return A character key.
#' @export
registry_key <- function(chapter, index) {
  paste0(chapter, ":", as.integer(index))
}

#' Convert a chunk registry into a full data frame
#'
#' Tolerant of legacy entries that don't yet have the `status`, `images`,
#' `error`, or `timestamp` fields (missing `status` is treated as `"ok"`,
#' missing `images` as none).
#'
#' @param registry A registry list, as returned by [registry_read()].
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `lines`, `label`,
#'   `eval`, `status`, `elapsed`, `hash`, `n_images`, `images` (paths joined
#'   with `"; "`), `error`, `timestamp`.
#' @export
registry_to_df <- function(registry) {
  if (length(registry) == 0L) {
    return(data.frame(
      chapter = character(), chunk = integer(), lines = character(),
      label = character(), eval = logical(), status = character(),
      elapsed = numeric(), hash = character(), n_images = integer(),
      images = character(), error = character(), timestamp = character(),
      stringsAsFactors = FALSE
    ))
  }

  keys <- names(registry)
  parts <- strsplit(keys, ":", fixed = TRUE)
  chapter <- vapply(parts, `[`, character(1L), 1L)
  chunk <- as.integer(vapply(parts, `[`, character(1L), 2L))

  images_list <- lapply(registry, function(x) {
    im <- x[["images"]]
    if (is.null(im)) character(0) else as.character(im)
  })

  df <- data.frame(
    chapter = chapter,
    chunk = chunk,
    lines = vapply(registry, function(x) as.character(x$lines %||% ""), character(1L)),
    label = vapply(registry, function(x) as.character(x$label %||% ""), character(1L)),
    eval = vapply(registry, function(x) {
      v <- x$eval
      if (is.null(v)) NA else isTRUE(v)
    }, logical(1L)),
    status = vapply(registry, function(x) as.character(x$status %||% "ok"), character(1L)),
    elapsed = vapply(registry, function(x) as.numeric(x$elapsed %||% NA), numeric(1L)),
    hash = vapply(registry, function(x) as.character(x$hash %||% ""), character(1L)),
    n_images = vapply(images_list, length, integer(1L)),
    images = vapply(images_list, function(x) paste(x, collapse = "; "), character(1L)),
    error = vapply(registry, function(x) as.character(x$error %||% ""), character(1L)),
    timestamp = vapply(registry, function(x) as.character(x$timestamp %||% ""), character(1L)),
    stringsAsFactors = FALSE
  )
  rownames(df) <- NULL
  df
}

#' Summarise a registry as a data frame
#'
#' Useful for identifying the slowest chunks after a run. Only chunks that
#' completed successfully (`status == "ok"`) are included; see
#' [list_failed_chunks()] for chunks that errored.
#'
#' @param registry A registry list.
#' @param n Maximum number of rows to return.
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `lines`, `label`,
#'   `elapsed`, `hash`.
#' @export
chunk_report <- function(registry, n = 10L) {
  df <- registry_to_df(registry)
  df <- df[df$status != "error", , drop = FALSE]
  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df <- df[, c("chapter", "chunk", "lines", "label", "elapsed", "hash"), drop = FALSE]
  utils::head(df, n)
}

#' List chunks that failed on their last run
#'
#' @param registry A registry list, as returned by [registry_read()].
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `lines`, `label`,
#'   `eval`, `elapsed`, `error`, `timestamp`, sorted by timestamp descending
#'   (most recent failure first).
#' @export
list_failed_chunks <- function(registry) {
  df <- registry_to_df(registry)
  df <- df[df$status == "error",
           c("chapter", "chunk", "lines", "label", "eval", "elapsed", "error", "timestamp"),
           drop = FALSE]
  df <- df[order(df$timestamp, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df
}

#' List the slowest completed chunks, optionally filtered by `eval`
#'
#' Handy for finding `eval: true` chunks (i.e. those Quarto actually
#' re-executes on every render) that are worth investigating or converting to
#' `eval: false` with a cached, pre-rendered output.
#'
#' @param registry A registry list, as returned by [registry_read()].
#' @param eval_only If `TRUE` (the default), only `eval: true` chunks are
#'   returned; if `FALSE`, only `eval: false` chunks; if `NULL`, no filtering
#'   on `eval` is applied.
#' @param n Maximum number of rows to return (default `Inf`, i.e. all).
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `lines`, `label`,
#'   `eval`, `elapsed`, `hash`, sorted by elapsed descending.
#' @export
list_slow_chunks <- function(registry, eval_only = TRUE, n = Inf) {
  df <- registry_to_df(registry)
  df <- df[df$status == "ok", , drop = FALSE]
  if (!is.null(eval_only)) {
    df <- df[!is.na(df$eval) & df$eval == eval_only, , drop = FALSE]
  }
  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df <- df[, c("chapter", "chunk", "lines", "label", "eval", "elapsed", "hash"), drop = FALSE]
  if (is.finite(n)) {
    df <- utils::head(df, n)
  }
  df
}

#' List chunks that produced one or more saved plot images
#'
#' Useful for deciding whether a slow, plot-producing chunk is worth marking
#' `eval: false` and replacing with a `knitr::include_graphics()` chunk that
#' points at the (reviewed/moved) saved image.
#'
#' @param registry A registry list, as returned by [registry_read()].
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `label`, `eval`,
#'   `elapsed`, `n_images`, `images` (paths joined with `"; "`), sorted by
#'   elapsed descending.
#' @export
list_chunks_with_images <- function(registry) {
  df <- registry_to_df(registry)
  df <- df[df$n_images > 0L,
           c("chapter", "chunk", "label", "eval", "elapsed", "n_images", "images"),
           drop = FALSE]
  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df
}

#' Full chunk summary data frame
#'
#' Exported wrapper around [registry_to_df()], provided as a stable public
#' entry point for building custom filters/reports.
#'
#' @param registry A registry list, as returned by [registry_read()].
#'
#' @return See [registry_to_df()].
#' @export
chunk_summary_df <- function(registry) {
  registry_to_df(registry)
}

#' Write the full chunk summary to a CSV file
#'
#' @param registry A registry list, as returned by [registry_read()].
#' @param path Output CSV path.
#'
#' @return `path`, invisibly.
#' @export
write_chunk_summary <- function(registry, path) {
  df <- chunk_summary_df(registry)
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

#' Read a structured event log written by a generated data-generation script
#'
#' The log is a sequence of flow-style YAML mappings, one per line (e.g.
#' `- {event: "chunk_error", chapter: "dc_regularize", ...}`), and is
#' therefore a valid YAML document that can be parsed in one shot.
#'
#' @param path Path to the `.log` file.
#'
#' @return A list of event records (each a named list); `list()` if the file
#'   does not exist.
#' @export
read_event_log <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  yaml::read_yaml(path)
}

#' Flatten an event log into a data frame
#'
#' @param events A list of event records, as returned by [read_event_log()].
#'
#' @return A `data.frame` with one row per event and one column per field seen
#'   across all events (missing fields filled with `NA`).
#' @export
event_log_to_df <- function(events) {
  if (length(events) == 0L) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  all_keys <- unique(unlist(lapply(events, names)))
  rows <- lapply(events, function(e) {
    vals <- lapply(all_keys, function(k) {
      v <- e[[k]]
      if (is.null(v)) NA_character_ else as.character(v)
    })
    names(vals) <- all_keys
    as.data.frame(vals, stringsAsFactors = FALSE)
  })
  df <- do.call(rbind, rows)
  rownames(df) <- NULL
  df
}
