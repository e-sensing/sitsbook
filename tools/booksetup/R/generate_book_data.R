#' Generate all book temp data
#'
#' Convenience wrapper around [build_data_script()] that builds the data
#' generation script and immediately sources it in a fresh environment. This is
#' the fastest way to populate `~/sitsbook/tempdir/` when the book source is
#' already set up.
#'
#' @param book_dir Path to the book project root (must contain `_quarto.yml`).
#' @param output Path for the generated R script. Defaults to a temporary file.
#' @param ... Additional arguments passed to [build_data_script()].
#'
#' @return The path to the generated script, invisibly.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' generate_book_data("/home/rolf/gh/sitsbook")
#' }
generate_book_data <- function(book_dir,
                               output = file.path(
                                 "tempdir",
                                 paste0("generate_book_data_",
                                        format(Sys.time(), "%Y%m%d_%H%M%S"),
                                        ".R")
                               ),
                               ...) {
  script_path <- build_data_script(
    book_dir = book_dir,
    output = output,
    ...
  )
  message("Data-generation script written to: ", script_path)
  message("Sourcing script ...")
  source(script_path, local = new.env(), echo = FALSE)
  message("Done.")
  invisible(script_path)
}
