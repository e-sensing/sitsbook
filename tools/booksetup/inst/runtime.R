# Runtime helpers for the generated sitsbook data script.
# This file is copied verbatim into the header of every generated script.

`%||%` <- function(x, y) if (is.null(x)) y else x

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

# Write one flow-style YAML mapping per event, e.g.:
#   - {event: "chunk_ok", time: "2026-08-08T10:00:00.000", chapter: "intro", ...}
# The whole log file is therefore a valid YAML sequence, parseable in one shot
# via `yaml::read_yaml()`, without mixing in raw chunk stdout or default
# warning/error dumps.
yaml_flow_scalar <- function(x) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    return("null")
  }
  if (is.numeric(x) || is.logical(x)) {
    return(as.character(x))
  }
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub("\"", "\\\\\"", x)
  x <- gsub("\n", "\\\\n", x)
  x <- gsub("\t", "\\\\t", x)
  paste0("\"", x, "\"")
}

log_event <- function(log_con, event, ...) {
  fields <- c(list(event = event, time = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3")), list(...))
  parts <- vapply(names(fields), function(k) paste0(k, ": ", yaml_flow_scalar(fields[[k]])),
                  character(1L))
  writeLines(paste0("- {", paste(parts, collapse = ", "), "}"), log_con)
  flush(log_con)
}

run_chapter <- function(chapter_name, chapter_i, n_chapters, body) {
  message(sprintf("[%d/%d] %s", chapter_i, n_chapters, chapter_name))
  log_event(log_con, "chapter_start", chapter = chapter_name, index = chapter_i,
            total = n_chapters)
  start <- proc.time()["elapsed"]
  tryCatch(
    body(),
    error = function(e) {
      msg <- conditionMessage(e)
      log_event(log_con, "chapter_error", chapter = chapter_name, message = msg)
      message("  [", chapter_name, "] chapter aborted (see log)")
      errors <<- c(errors, msg)
    }
  )
  elapsed <- as.numeric(proc.time()["elapsed"] - start)
  chapter_times[chapter_i] <<- elapsed
  avg <- mean(chapter_times[chapter_times > 0])
  remaining <- n_chapters - chapter_i
  eta <- if (is.finite(avg)) format(Sys.time() + remaining * avg) else NA_character_
  log_event(log_con, "chapter_end", chapter = chapter_name, elapsed = elapsed,
            avg = if (is.finite(avg)) avg else NA_real_, remaining = remaining, eta = eta)
}

# Build a full data frame from a registry list, tolerant of legacy entries
# that don't have the newer `status`/`images`/`error`/`timestamp` fields.
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

chunk_report <- function(registry, n = 10L) {
  df <- registry_to_df(registry)
  df <- df[df$status != "error", , drop = FALSE]
  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df <- df[, c("chapter", "chunk", "lines", "label", "elapsed", "hash"), drop = FALSE]
  utils::head(df, n)
}

list_failed_chunks <- function(registry) {
  df <- registry_to_df(registry)
  df <- df[df$status == "error",
           c("chapter", "chunk", "lines", "label", "eval", "elapsed", "error", "timestamp"),
           drop = FALSE]
  df <- df[order(df$timestamp, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df
}

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

list_chunks_with_images <- function(registry) {
  df <- registry_to_df(registry)
  df <- df[df$n_images > 0L,
           c("chapter", "chunk", "label", "eval", "elapsed", "n_images", "images"),
           drop = FALSE]
  df <- df[order(df$elapsed, decreasing = TRUE), , drop = FALSE]
  rownames(df) <- NULL
  df
}

chunk_summary_df <- function(registry) {
  registry_to_df(registry)
}

write_chunk_summary <- function(registry, path) {
  df <- chunk_summary_df(registry)
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

# Save every plot recorded while evaluating a chunk (base graphics, ggplot2,
# tmap, etc.) as a normalized PNG file under `image_dir/<chapter_name>/`.
#
# `results` is the list returned by `evaluate::evaluate()`; plots appear in it
# as objects inheriting from `"recordedplot"`. Returns the paths of the files
# written (character(0) if the chunk produced no plots).
save_chunk_plots <- function(results, image_dir, chapter_name, chunk_i, label,
                             width, height, res) {
  plots <- Filter(function(x) inherits(x, "recordedplot"), results)
  if (length(plots) == 0L) {
    return(character())
  }

  out_dir <- file.path(image_dir, chapter_name)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  slug <- if (!is.null(label) && nzchar(label)) label else paste0("chunk_", chunk_i)

  paths <- character(length(plots))
  for (k in seq_along(plots)) {
    fname <- sprintf("%s_%02d-%s_p%d.png", chapter_name, chunk_i, slug, k)
    path <- file.path(out_dir, fname)
    grDevices::png(filename = path, width = width, height = height, res = res)
    tryCatch(
      grDevices::replayPlot(plots[[k]]),
      error = function(e) {
        message("  could not save plot ", k, ": ", conditionMessage(e))
      },
      finally = grDevices::dev.off()
    )
    paths[k] <- path
  }
  paths
}

run_chunk <- function(chapter_name, chunk_i, n_chunks, start_line, end_line,
                      label, hash, eval, env, code) {
  key <- paste0(chapter_name, ":", chunk_i)
  lines_str <- paste0(start_line, "-", end_line)
  existing <- booksetup_registry[[key]]
  existing_ok <- !is.null(existing) && !identical(existing$status, "error")

  if (identical(eval, FALSE) && existing_ok && identical(existing$hash, hash)) {
    if (!identical(existing$label, label)) {
      booksetup_registry[[key]]$label <<- label
      registry_write(registry_file, booksetup_registry)
    }
    log_event(log_con, "chunk_skip", chapter = chapter_name, chunk = chunk_i,
              lines = lines_str, label = label, elapsed = existing$elapsed)
    message(sprintf("  [%s] chunk %d/%d (%s) - SKIPPED (elapsed %.1fs)",
                    chapter_name, chunk_i, n_chunks, label,
                    as.numeric(existing$elapsed %||% 0)))
    return(invisible(NULL))
  }

  start <- proc.time()["elapsed"]
  results <- evaluate::evaluate(
    code,
    envir = env,
    new_device = TRUE,
    stop_on_error = 1L,
    keep_warning = TRUE,
    keep_message = TRUE
  )
  elapsed <- as.numeric(proc.time()["elapsed"] - start)

  warnings_found <- Filter(function(x) inherits(x, "warning"), results)
  for (w in warnings_found) {
    msg <- conditionMessage(w)
    log_event(log_con, "chunk_warning", chapter = chapter_name, chunk = chunk_i,
              lines = lines_str, label = label, message = msg)
    message(sprintf("  WARNING [%s chunk %d]: %s", chapter_name, chunk_i, msg))
  }

  errors_found <- Filter(function(x) inherits(x, "error"), results)
  if (length(errors_found) > 0L) {
    err <- conditionMessage(errors_found[[1L]])
    log_event(log_con, "chunk_error", chapter = chapter_name, chunk = chunk_i,
              lines = lines_str, label = label, message = err)
    booksetup_registry[[key]] <<- list(
      status = "error",
      hash = hash,
      lines = lines_str,
      label = label,
      eval = eval,
      elapsed = elapsed,
      error = err,
      timestamp = format(Sys.time())
    )
    registry_write(registry_file, booksetup_registry)
    message(sprintf("  ERROR [%s chunk %d]: %s", chapter_name, chunk_i, err))
    stop("ERROR in ", chapter_name, " chunk ", chunk_i,
         " lines ", start_line, "-", end_line, ": ", err,
         call. = FALSE)
  }

  saved <- save_chunk_plots(results, image_dir, chapter_name, chunk_i, label,
                            image_width, image_height, image_res)

  booksetup_registry[[key]] <<- list(
    status = "ok",
    hash = hash,
    elapsed = elapsed,
    lines = lines_str,
    label = label,
    eval = eval,
    images = saved
  )
  registry_write(registry_file, booksetup_registry)

  log_event(log_con, "chunk_ok", chapter = chapter_name, chunk = chunk_i,
            lines = lines_str, label = label, eval = eval, elapsed = elapsed,
            images = length(saved))
  message(sprintf("  [%s] chunk %d/%d (%s) - %.1fs%s", chapter_name, chunk_i, n_chunks,
                  label, elapsed,
                  if (length(saved) > 0L) sprintf(" [%d image(s)]", length(saved)) else ""))

  invisible(NULL)
}
