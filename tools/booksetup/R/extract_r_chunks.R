#' Extract all R code chunks from a Quarto / R Markdown file
#'
#' Reads a `.qmd` or `.Rmd` file and returns the R code it contains. All R chunks
#' are extracted, including those marked `#| eval: false`, so that the returned
#' code can be used for data generation. Chunk option lines (`#| ...`) are
#' stripped, but the actual code is preserved.
#'
#' The returned list preserves the source location of every chunk. Each element
#' is a character vector with attributes `start_line` and `end_line` giving the
#' line numbers of the opening and closing fences in the original file, and
#' optionally a `label` attribute when the chunk header contains one.
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
#' attr(chunks[[1]], "start_line")
extract_r_chunks <- function(qmd) {
  if (!file.exists(qmd)) {
    stop("File does not exist: ", qmd)
  }

  lines <- readLines(qmd, warn = FALSE)
  chunks <- list()
  in_chunk <- FALSE
  current <- character()
  label <- NULL
  start_line <- NA_integer_
  chunk_count <- 0L

  for (i in seq_along(lines)) {
    line <- lines[i]
    if (!in_chunk) {
      if (grepl("^```\\{r(\\}|[[:space:]].*\\})\\s*$", line)) {
        in_chunk <- TRUE
        current <- character()
        start_line <- i
        label <- .extract_chunk_label(line)
      }
    } else {
      if (grepl("^```[[:space:]]*$", line)) {
        in_chunk <- FALSE
        end_line <- i
        chunk_count <- chunk_count + 1L
        nm <- label %||% paste0("chunk_", chunk_count)
        chunk <- current
        attr(chunk, "start_line") <- start_line
        attr(chunk, "end_line") <- end_line
        attr(chunk, "label") <- label
        chunks[[nm]] <- chunk
        label <- NULL
        start_line <- NA_integer_
      } else if (!grepl("^#\\|", line)) {
        current <- c(current, line)
      }
    }
  }

  chunks
}

.extract_chunk_label <- function(header) {
  # ```{r}        -> no label
  # ```{r}       -> no label (trailing whitespace)
  # ```{r foo}    -> label "foo"
  # ```{r foo, x} -> label "foo"
  inner <- sub("^```\\{r\\s*", "", header)
  inner <- sub("\\}\\s*$", "", inner)
  inner <- trimws(inner)
  if (nzchar(inner)) {
    strsplit(inner, "[,\\s]+")[[1L]][1L]
  } else {
    NULL
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x
