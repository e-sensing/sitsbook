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

#' Summarise a registry as a data frame
#'
#' Useful for identifying the slowest chunks after a run.
#'
#' @param registry A registry list.
#' @param n Maximum number of rows to return.
#'
#' @return A `data.frame` with columns `chapter`, `chunk`, `lines`, `label`,
#'   `elapsed`, `hash`.
#' @export
chunk_report <- function(registry, n = 10L) {
  if (length(registry) == 0L) {
    return(data.frame(
      chapter = character(),
      chunk = integer(),
      lines = character(),
      label = character(),
      elapsed = numeric(),
      hash = character(),
      stringsAsFactors = FALSE
    ))
  }

  keys <- names(registry)
  parts <- strsplit(keys, ":", fixed = TRUE)
  chapter <- vapply(parts, `[`, character(1L), 1L)
  chunk <- as.integer(vapply(parts, `[`, character(1L), 2L))

  df <- data.frame(
    chapter = chapter,
    chunk = chunk,
    lines = vapply(registry, function(x) x$lines %||% "", character(1L)),
    label = vapply(registry, function(x) x$label %||% "", character(1L)),
    elapsed = vapply(registry, function(x) as.numeric(x$elapsed %||% 0), numeric(1L)),
    hash = vapply(registry, function(x) x$hash %||% "", character(1L)),
    stringsAsFactors = FALSE
  )

  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  utils::head(df, n)
}
