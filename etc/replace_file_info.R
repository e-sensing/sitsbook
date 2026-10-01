# -----------------------------------------------------------------------------
# Replace part of the `file_info` paths of a sits data cube.
#
# A sits data cube is a tibble with one row per tile and a nested `file_info`
# tibble in each row. `file_info` has one row per image, and its `path` column
# holds the file path of each image. This script rewrites a substring of those
# paths (e.g., an outdated storage root) with new text, returning a data cube
# that is still structurally valid: only the `path` values change, while every
# tile row, nested `file_info` and the cube's S3 classes are preserved.
# -----------------------------------------------------------------------------

library(sits)

#' Replace part of a data cube's file_info paths
#'
#' @param cube        A sits data cube (raster_cube or a derived cube).
#' @param pattern     Text to look for inside each image path.
#' @param replacement New text to substitute for `pattern`.
#' @param column      Name of the `file_info` column to edit. Default "path".
#' @param fixed       If TRUE (default), `pattern` is matched literally; if
#'                    FALSE, it is treated as a regular expression.
#'
#' @return The data cube with updated paths, preserving its structure/class.
replace_cube_file_info <- function(cube,
                                   pattern,
                                   replacement,
                                   column = "path",
                                   fixed = TRUE) {
    stopifnot(
        inherits(cube, "tbl_df"),
        "file_info" %in% names(cube),
        length(pattern) == 1L,
        length(replacement) == 1L
    )
    # Edit only the target column inside each tile's nested file_info, keeping
    # the cube object (and therefore its S3 classes) untouched otherwise.
    cube[["file_info"]] <- purrr::map(cube[["file_info"]], function(fi) {
        if (!column %in% names(fi)) {
            stop("column '", column, "' not found in file_info", call. = FALSE)
        }
        fi[[column]] <- gsub(pattern, replacement, fi[[column]], fixed = fixed)
        fi
    })
    cube
}

# -----------------------------------------------------------------------------
# Example
# -----------------------------------------------------------------------------
# Rewrite the storage root of every image path in `landsat_cube`, e.g. after
# moving files to a new directory. `val` holds the new text.
#
# new_cube <- replace_cube_file_info(
#     cube        = landsat_cube,
#     pattern     = "/old/data/root",
#     replacement = val
# )
#
# Confirm the result is still a valid cube:
# sits_bbox(new_cube)     # cube accessors keep working
# class(new_cube)         # original cube classes are preserved
