#' Extract all R code chunks from a Quarto / R Markdown file
#'
#' Reads a `.qmd` or `.Rmd` file and returns the R code it contains. All R chunks
#' are extracted, including those marked `#| eval: false`, so that the returned
#' code can be used for data generation. Chunk option lines (`#| ...`) are
#' stripped, but the actual code is preserved.
#'
#' @param qmd Path to a Quarto or R Markdown file.
#'
#' @return A named list of character vectors. Each element contains the code
#'   lines of one R chunk. Names are chunk labels when available; otherwise
#'   `chunk_1`, `chunk_2`, etc.
#'
#' @export
#'
#' @examples
#' sample <- system.file("extdata", "sample.qmd", package = "booksetup")
#' chunks <- extract_r_chunks(sample)
#' chunks
extract_r_chunks <- function(qmd) {
  if (!file.exists(qmd)) {
    stop("File does not exist: ", qmd)
  }

  lines <- readLines(qmd, warn = FALSE)
  chunks <- list()
  in_chunk <- FALSE
  current <- character()
  label <- NULL
  chunk_count <- 0L

  for (line in lines) {
    if (!in_chunk) {
      if (grepl("^```\\{r(\\}|[[:space:]].*\\})$", line)) {
        in_chunk <- TRUE
        current <- character()
        label <- .extract_chunk_label(line)
      }
    } else {
      if (grepl("^```[[:space:]]*$", line)) {
        in_chunk <- FALSE
        chunk_count <- chunk_count + 1L
        nm <- label %||% paste0("chunk_", chunk_count)
        chunks[[nm]] <- current
        label <- NULL
      } else if (!grepl("^#\\|", line)) {
        current <- c(current, line)
      }
    }
  }

  chunks
}

.extract_chunk_label <- function(header) {
  # ```{r}        -> no label
  # ```{r foo}    -> label "foo"
  # ```{r foo, x} -> label "foo"
  inner <- sub("^```\\{r\\s*", "", header)
  inner <- sub("\\}$", "", inner)
  inner <- trimws(inner)
  if (nzchar(inner)) {
    strsplit(inner, "[,\\s]+")[[1L]][1L]
  } else {
    NULL
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x
