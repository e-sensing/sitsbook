#' List chapter Quarto files in book order
#'
#' Reads the `_quarto.yml` of a Quarto book and returns the `.qmd` chapter files
#' in the order they appear. The function handles flat chapter lists as well as
#' nested `part: ... / chapters: ...` structures.
#'
#' @param book_dir Path to the book project root (must contain `_quarto.yml`).
#'
#' @return A character vector of `.qmd` file paths, in book order.
#'
#' @export
#'
#' @examples
#' book_dir <- system.file("extdata", package = "booksetup")
#' chapter_files(book_dir)
chapter_files <- function(book_dir) {
  qmd_yml <- file.path(book_dir, "_quarto.yml")
  if (!file.exists(qmd_yml)) {
    stop("No _quarto.yml found in ", book_dir)
  }

  cfg <- yaml::read_yaml(qmd_yml)
  files <- collect_qmds(cfg$book$chapters)

  if (length(files) == 0L) {
    warning("No .qmd chapter files found in ", qmd_yml)
  }

  file.path(book_dir, files)
}

collect_qmds <- function(x) {
  if (is.character(x)) {
    return(x)
  }
  if (!is.list(x)) {
    return(character())
  }
  out <- character()
  for (i in seq_along(x)) {
    el <- x[[i]]
    if (is.character(el)) {
      out <- c(out, el)
    } else if (is.list(el)) {
      # A chapter/part entry can itself be a named list (e.g., part + chapters).
      # Recurse into all of its elements.
      out <- c(out, collect_qmds(el))
    }
  }
  out
}
