#' Check whether a chapter already has generated temporary data
#'
#' Looks inside the R temp directory for a given chapter and reports whether it
#' already contains files. This is used to skip re-running expensive
#' `sits_*()` calls when data is already present.
#'
#' @param chapter_name Bare chapter name, e.g. `"dc_cubeoperations"`.
#' @param tempdir Root temporary directory for generated R data. Defaults to
#'   `~/sitsbook/tempdir/R`.
#'
#' @return `TRUE` if the chapter directory exists and is non-empty, otherwise
#'   `FALSE`.
#'
#' @export
#'
#' @examples
#' has_chapter_data("dc_cubeoperations")
has_chapter_data <- function(chapter_name,
                               tempdir = path.expand("~/sitsbook/tempdir/R")) {
  dir_path <- file.path(tempdir, chapter_name)
  if (!dir.exists(dir_path)) {
    return(FALSE)
  }
  length(list.files(dir_path, all.files = TRUE, recursive = TRUE)) > 0L
}
