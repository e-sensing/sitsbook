# Runtime functions for book data generation.
#
# These are the execution engine: they run chapters and chunks, manage the
# registry, log events, and capture plots. They were originally in
# inst/runtime.R and copied into generated scripts; they now live here as
# proper (internal) package functions.

# ---- run state ----

#' Create a mutable run-state environment
#'
#' All mutable state that `run_chapter` and `run_chunk` need is held here,
#' passed explicitly instead of relying on `<<-` into free variables.
#'
#' @param registry_file Path to the YAML registry file.
#' @param log_file Path to the event log file.
#' @param image_dir Directory for saved chunk plots.
#' @param image_width,image_height,image_res PNG dimensions and resolution.
#' @param n_chapters Total number of chapters (for progress/ETA).
#'
#' @return An environment with fields: `registry_file`, `registry`,
#'   `log_con`, `errors`, `chapter_times`, `image_dir`, `image_width`,
#'   `image_height`, `image_res`.
#' @keywords internal
new_run_state <- function(registry_file,
                          log_file,
                          image_dir,
                          image_width = 2000L,
                          image_height = 1500L,
                          image_res = 150L,
                          n_chapters = 0L) {
  dir.create(dirname(registry_file), showWarnings = FALSE, recursive = TRUE)
  dir.create(image_dir, showWarnings = FALSE, recursive = TRUE)

  if (file.exists(log_file)) file.remove(log_file)
  log_con <- file(log_file, "w")

  state <- new.env(parent = emptyenv())
  state$registry_file <- registry_file
  state$registry <- registry_read(registry_file)
  state$log_con <- log_con
  state$errors <- character()
  state$chapter_times <- numeric(n_chapters)
  state$image_dir <- image_dir
  state$image_width <- image_width
  state$image_height <- image_height
  state$image_res <- image_res
  state$snapshot_dir <- file.path(dirname(registry_file), ".snapshots")
  state$snapshot_max_bytes <- 50e6
  state
}

#' Close a run-state (flush and close the log connection)
#' @keywords internal
close_run_state <- function(state) {
  tryCatch(close(state$log_con), error = function(e) NULL)
  invisible(NULL)
}

# ---- logging ----

#' Format a scalar for inline YAML output
#' @keywords internal
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

#' Write one flow-style YAML event to the log
#' @keywords internal
log_event <- function(log_con, event, ...) {
  fields <- c(
    list(event = event, time = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3")),
    list(...)
  )
  parts <- vapply(
    names(fields),
    function(k) paste0(k, ": ", yaml_flow_scalar(fields[[k]])),
    character(1L)
  )
  writeLines(paste0("- {", paste(parts, collapse = ", "), "}"), log_con)
  flush(log_con)
}

# ---- plot capture ----

#' Save plots produced by `evaluate::evaluate()` as PNG files
#'
#' @param results The list returned by `evaluate::evaluate()`.
#' @param image_dir Base directory for images.
#' @param chapter_name Chapter name (used as subdirectory).
#' @param chunk_i Chunk index.
#' @param label Chunk label.
#' @param width,height,res PNG dimensions and resolution.
#'
#' @return Character vector of saved file paths (empty if no plots).
#' @keywords internal
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

# ---- chunk execution ----

#' Run a single chunk, with registry-based skip logic
#'
#' @param state A run-state environment (from `new_run_state()`).
#' @param chapter_name Chapter name.
#' @param chunk_i Chunk index within the chapter.
#' @param n_chunks Total chunks in this chapter.
#' @param start_line,end_line Source line range in the `.qmd`.
#' @param label Chunk label.
#' @param hash MD5 hash of the chunk code.
#' @param eval Logical; the chunk's `eval` option.
#' @param env Environment in which to evaluate the chunk.
#' @param code Character vector of R code lines.
#'
#' @keywords internal
run_chunk <- function(state, chapter_name, chunk_i, n_chunks, start_line,
                      end_line, label, hash, eval, env, code) {
  key <- paste0(chapter_name, ":", chunk_i)
  lines_str <- paste0(start_line, "-", end_line)
  existing <- state$registry[[key]]
  existing_ok <- !is.null(existing) && !identical(existing$status, "error")

  if (identical(eval, FALSE) && existing_ok && identical(existing$hash, hash)) {
    if (!identical(existing$label, label)) {
      state$registry[[key]]$label <- label
      registry_write(state$registry_file, state$registry)
    }
    restore_chunk_env(key, env, state$snapshot_dir)
    log_event(state$log_con, "chunk_skip", chapter = chapter_name,
              chunk = chunk_i, lines = lines_str, label = label,
              elapsed = existing$elapsed)
    message(sprintf("  [%s] chunk %d/%d (%s) - SKIPPED (elapsed %.1fs)",
                    chapter_name, chunk_i, n_chunks, label,
                    as.numeric(existing$elapsed %||% 0)))
    return(invisible(NULL))
  }

  pre_vars <- ls(env, all.names = FALSE)
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
    log_event(state$log_con, "chunk_warning", chapter = chapter_name,
              chunk = chunk_i, lines = lines_str, label = label, message = msg)
    message(sprintf("  WARNING [%s chunk %d]: %s", chapter_name, chunk_i, msg))
  }

  errors_found <- Filter(function(x) inherits(x, "error"), results)
  if (length(errors_found) > 0L) {
    err <- conditionMessage(errors_found[[1L]])
    log_event(state$log_con, "chunk_error", chapter = chapter_name,
              chunk = chunk_i, lines = lines_str, label = label, message = err)
    state$registry[[key]] <- list(
      status = "error",
      hash = hash,
      lines = lines_str,
      label = label,
      eval = eval,
      elapsed = elapsed,
      error = err,
      timestamp = format(Sys.time())
    )
    registry_write(state$registry_file, state$registry)
    message(sprintf("  ERROR [%s chunk %d]: %s", chapter_name, chunk_i, err))
    stop("ERROR in ", chapter_name, " chunk ", chunk_i,
         " lines ", start_line, "-", end_line, ": ", err,
         call. = FALSE)
  }

  saved <- save_chunk_plots(results, state$image_dir, chapter_name, chunk_i,
                            label, state$image_width, state$image_height,
                            state$image_res)

  state$registry[[key]] <- list(
    status = "ok",
    hash = hash,
    elapsed = elapsed,
    lines = lines_str,
    label = label,
    eval = eval,
    images = saved
  )
  registry_write(state$registry_file, state$registry)

  if (identical(eval, FALSE)) {
    snapshot_chunk_env(key, env, pre_vars, state$snapshot_dir,
                      state$snapshot_max_bytes)
  }

  log_event(state$log_con, "chunk_ok", chapter = chapter_name,
            chunk = chunk_i, lines = lines_str, label = label, eval = eval,
            elapsed = elapsed, images = length(saved))
  message(sprintf("  [%s] chunk %d/%d (%s) - %.1fs%s", chapter_name,
                  chunk_i, n_chunks, label, elapsed,
                  if (length(saved) > 0L) sprintf(" [%d image(s)]", length(saved)) else ""))

  invisible(NULL)
}

# ---- chapter execution ----

#' Run all chunks for one chapter
#'
#' @param state A run-state environment.
#' @param chapter_name Chapter name.
#' @param chapter_i Chapter index (1-based).
#' @param n_chapters Total number of chapters.
#' @param body A zero-argument function that calls `run_chunk()` for each chunk.
#'
#' @keywords internal
run_chapter <- function(state, chapter_name, chapter_i, n_chapters, body) {
  message(sprintf("[%d/%d] %s", chapter_i, n_chapters, chapter_name))
  log_event(state$log_con, "chapter_start", chapter = chapter_name,
            index = chapter_i, total = n_chapters)
  start <- proc.time()["elapsed"]
  tryCatch(
    body(),
    error = function(e) {
      msg <- conditionMessage(e)
      log_event(state$log_con, "chapter_error", chapter = chapter_name,
                message = msg)
      message("  [", chapter_name, "] chapter aborted (see log)")
      state$errors <- c(state$errors, msg)
    }
  )
  elapsed <- as.numeric(proc.time()["elapsed"] - start)
  state$chapter_times[chapter_i] <- elapsed
  avg <- mean(state$chapter_times[state$chapter_times > 0])
  remaining <- n_chapters - chapter_i
  eta <- if (is.finite(avg)) format(Sys.time() + remaining * avg) else NA_character_
  log_event(state$log_con, "chapter_end", chapter = chapter_name,
            elapsed = elapsed,
            avg = if (is.finite(avg)) avg else NA_real_,
            remaining = remaining, eta = eta)
}
