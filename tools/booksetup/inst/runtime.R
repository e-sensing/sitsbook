# Runtime helpers for the generated sitsbook data script.
# This file is copied verbatim into the header of every generated script.

registry_read <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  yaml::read_yaml(path)
}

registry_write <- function(path, registry) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  yaml::write_yaml(registry, path)
  invisible(path)
}

run_chapter <- function(chapter_name, chapter_i, n_chapters, body) {
  message("[", chapter_i, "/", n_chapters, "] ", chapter_name,
          " -- ", format(Sys.time()))
  start <- proc.time()["elapsed"]
  body()
  elapsed <- proc.time()["elapsed"] - start
  chapter_times[chapter_i] <<- elapsed
  avg <- mean(chapter_times[chapter_times > 0])
  remaining <- n_chapters - chapter_i
  eta <- if (is.finite(avg)) Sys.time() + remaining * avg else NA
  message("    chapter elapsed: ", round(elapsed, 1), "s; avg: ", round(avg, 1),
          "s; remaining: ", remaining, "; ETA: ", format(eta))
}

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
  chapter <- vapply(parts, function(x) x[[1L]], character(1L))
  chunk <- as.integer(vapply(parts, function(x) x[[2L]], character(1L)))

  get_field <- function(x, field) {
    val <- x[[field]]
    if (is.null(val)) "" else as.character(val)
  }

  df <- data.frame(
    chapter = chapter,
    chunk = chunk,
    lines = vapply(registry, function(x) get_field(x, "lines"), character(1L)),
    label = vapply(registry, function(x) get_field(x, "label"), character(1L)),
    elapsed = vapply(registry, function(x) as.numeric(get_field(x, "elapsed")), numeric(1L)),
    hash = vapply(registry, function(x) get_field(x, "hash"), character(1L)),
    stringsAsFactors = FALSE
  )

  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  utils::head(df, n)
}

run_chunk <- function(chapter_name, chunk_i, n_chunks, start_line, end_line,
                      label, hash, env, expr) {
  key <- paste0(chapter_name, ":", chunk_i)
  existing <- booksetup_registry[[key]]
  if (!is.null(existing) && identical(existing$hash, hash)) {
    message("    [chunk ", chunk_i, "/", n_chunks, "] lines ", start_line,
            "-", end_line, " (", label, ") - SKIPPED (elapsed ",
            round(existing$elapsed, 1), "s)")
    return(invisible(NULL))
  }

  message("    [chunk ", chunk_i, "/", n_chunks, "] lines ", start_line,
          "-", end_line, " (", label, ")")
  start <- proc.time()["elapsed"]
  err <- NULL
  tryCatch(
    eval(expr, env),
    error = function(e) {
      err <<- conditionMessage(e)
      msg <- paste0("ERROR in ", chapter_name, " chunk ", chunk_i,
                    " lines ", start_line, "-", end_line, ": ", err)
      message(msg)
      errors <<- c(errors, msg)
    }
  )
  elapsed <- proc.time()["elapsed"] - start
  if (is.null(err)) {
    booksetup_registry[[key]] <<- list(
      hash = hash,
      elapsed = elapsed,
      lines = paste0(start_line, "-", end_line),
      label = label
    )
    registry_write(registry_file, booksetup_registry)
    message("      elapsed: ", round(elapsed, 1), "s")
  }
  invisible(NULL)
}
