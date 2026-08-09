#' Generate all book temp data
#'
#' Runs every chapter's R chunks directly (extract, evaluate, skip/cache via
#' registry, capture plots). This is the primary entry point for populating
#' `~/sitsbook/tempdir/`.
#'
#' @param book_dir Path to the book project root (must contain `_quarto.yml`).
#' @param chapters Optional character vector of chapter names (without `.qmd`)
#'   to limit the run. If `NULL` (the default), all chapters are included.
#' @param exclude Optional character vector of chapter names to skip.
#' @param registry Path to the YAML chunk-completion registry. Defaults to
#'   [registry_path()].
#' @param python_sync If `TRUE` (the default), rsync R data to the Python
#'   temp directory after all chapters have run.
#' @param image_dir Directory where chunk plots are saved as PNG files,
#'   one sub-directory per chapter. Defaults to `generated_images/` next to
#'   the registry file.
#' @param image_width,image_height,image_res Pixel width/height and resolution
#'   (dpi) for saved chunk plots.
#' @param log_file Path for the structured YAML event log. Defaults to
#'   a timestamped `.log` file under `tempdir/` in the current directory.
#'
#' @return The path to the registry file, invisibly.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' generate_book_data("/home/rolf/gh/sitsbook")
#' }
generate_book_data <- function(book_dir,
                               chapters = NULL,
                               exclude = NULL,
                               registry = registry_path(),
                               python_sync = TRUE,
                               image_dir = file.path(
                                 dirname(registry),
                                 "generated_images"
                               ),
                               image_width = 2000L,
                               image_height = 1500L,
                               image_res = 150L,
                               log_file = file.path(
                                 "tempdir",
                                 paste0("generate_book_data_",
                                        format(Sys.time(), "%Y%m%d_%H%M%S"),
                                        ".log")
                               )) {

  qmds <- resolve_chapters(book_dir, chapters, exclude)
  n_chapters <- length(qmds)

  log_dir <- dirname(log_file)
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }

  state <- new_run_state(
    registry_file = normalizePath(registry, winslash = "/", mustWork = FALSE),
    log_file = log_file,
    image_dir = normalizePath(image_dir, winslash = "/", mustWork = FALSE),
    image_width = image_width,
    image_height = image_height,
    image_res = image_res,
    n_chapters = n_chapters
  )
  on.exit(close_run_state(state), add = TRUE)

  grDevices::pdf(file = NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  start_global <- Sys.time()
  message("Starting book data generation at ", format(start_global))
  log_event(state$log_con, "run_start", n_chapters = n_chapters)

  for (i in seq_along(qmds)) {
    chapter_name <- names(qmds)[i]
    qmd <- qmds[[i]]
    chunks <- extract_r_chunks(qmd)

    run_chapter(state, chapter_name, i, n_chapters, function() {
      env <- new.env(parent = globalenv())
      for (j in seq_along(chunks)) {
        chunk <- chunks[[j]]
        code <- chunk
        code <- code[!grepl(
          "install\\.packages|::install_github|::install|BiocManager::install",
          code
        )]
        start_line <- attr(chunk, "start_line", exact = TRUE) %||% NA_integer_
        end_line <- attr(chunk, "end_line", exact = TRUE) %||% NA_integer_
        label <- attr(chunk, "label", exact = TRUE) %||% ""
        if (!nzchar(label)) label <- names(chunks)[j]
        eval_flag <- attr(chunk, "eval", exact = TRUE) %||% TRUE

        run_chunk(state, chapter_name, j, length(chunks), start_line,
                  end_line, label, chunk_hash(code), eval_flag, env, code)
      }
    })
  }

  if (python_sync) {
    message("Syncing R data to Python temp directory...")
    system("rsync -a ~/sitsbook/tempdir/R/ ~/sitsbook/tempdir/Python/")
  }

  summary_csv <- file.path(dirname(state$registry_file), "chunk_summary.csv")
  write_chunk_summary(state$registry, summary_csv)
  message("Chunk summary written to: ", summary_csv)

  end_global <- Sys.time()
  log_event(state$log_con, "run_end",
            elapsed_min = as.numeric(difftime(end_global, start_global,
                                              units = "mins")),
            errors = length(state$errors))

  message("Book data generation finished at ", format(end_global))
  message("Total time: ",
          round(difftime(end_global, start_global, units = "mins"), 1),
          " minutes")

  if (length(state$errors) > 0L) {
    message("Errors encountered:")
    for (err in state$errors) message(err)
    stop("Some chapters failed; see ", log_file, " and ", summary_csv, ".",
         call. = FALSE)
  }

  invisible(state$registry_file)
}

#' Resolve chapter list from book_dir with optional filters
#'
#' Shared logic used by both [generate_book_data()] and [build_data_script()].
#'
#' @param book_dir Path to the book project root.
#' @param chapters Optional chapter names to include.
#' @param exclude Optional chapter names to exclude.
#'
#' @return A named character vector of `.qmd` file paths.
#' @keywords internal
resolve_chapters <- function(book_dir, chapters = NULL, exclude = NULL) {
  qmds <- chapter_files(book_dir)
  names(qmds) <- tools::file_path_sans_ext(basename(qmds))

  if (!is.null(chapters)) {
    missing <- setdiff(chapters, names(qmds))
    if (length(missing) > 0L) {
      stop("Requested chapters not found in _quarto.yml: ",
           paste(missing, collapse = ", "))
    }
    qmds <- qmds[chapters]
  }

  if (!is.null(exclude)) {
    unknown <- setdiff(exclude, names(qmds))
    if (length(unknown) > 0L) {
      warning("Excluded chapters not found: ", paste(unknown, collapse = ", "))
      exclude <- setdiff(exclude, unknown)
    }
    qmds <- qmds[setdiff(names(qmds), exclude)]
  }

  if (length(qmds) == 0L) {
    stop("No chapters selected after applying chapters/exclude.")
  }
  qmds
}
