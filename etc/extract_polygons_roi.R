# Extract polygons from a GeoPackage that fall inside a region of interest (ROI).
#
# Usage examples are at the bottom of the file.

library(sf)

#' Build an sf ROI polygon from a bounding box or pass through an existing sf object
#'
#' @param roi Either:
#'   - a named numeric vector/list with `lon_min`, `lat_min`, `lon_max`, `lat_max`
#'     (assumed to be in EPSG:4326 unless `crs` is supplied), or
#'   - an `sf`/`sfc` object (used as-is).
#' @param crs CRS for a bounding-box ROI. Defaults to EPSG:4326.
#' @return An `sfc` geometry for the ROI.
#' 
as_roi_geometry <- function(roi, crs = 4326) {
  if (inherits(roi, c("sf", "sfc"))) {
    return(st_geometry(roi))
  }

  required <- c("lon_min", "lat_min", "lon_max", "lat_max")
  if (!all(required %in% names(roi))) {
    stop(
      "`roi` must be an sf/sfc object or a named vector with: ",
      paste(required, collapse = ", ")
    )
  }

  bbox <- st_bbox(
    c(
      xmin = roi[["lon_min"]],
      ymin = roi[["lat_min"]],
      xmax = roi[["lon_max"]],
      ymax = roi[["lat_max"]]
    ),
    crs = st_crs(crs)
  )
  st_as_sfc(bbox)
}

#' Extract polygons from a GeoPackage that fall inside an ROI
#'
#' @param gpkg_path Path to the input `.gpkg` file.
#' @param roi ROI as a bounding-box vector or an `sf`/`sfc` object (see
#'   [as_roi_geometry()]).
#' @param layer Optional layer name. If `NULL`, the first layer is read (with a
#'   message when the file contains more than one).
#' @param predicate Spatial relationship to test against the ROI. Use
#'   `"intersects"` (default) to keep polygons that touch or overlap the ROI, or
#'   `"within"` to keep only polygons contained entirely inside it.
#' @param roi_crs CRS for a bounding-box ROI. Defaults to EPSG:4326.
#' @param crop If `TRUE`, clip the selected polygons to the ROI boundary with
#'   [sf::st_intersection()] so that parts extending beyond the ROI are removed.
#'   If `FALSE` (default), whole polygons are returned unmodified.
#' @param out_path Optional path to write the result as a new `.gpkg`. If `NULL`,
#'   nothing is written.
#' @return An `sf` object with the selected (and optionally cropped) polygons.
extract_polygons_in_roi <- function(gpkg_path,
                                     roi,
                                     layer = NULL,
                                     predicate = c("intersects", "within"),
                                     roi_crs = 4326,
                                     crop = FALSE,
                                     out_path = NULL) {
  predicate <- match.arg(predicate)

  if (!file.exists(gpkg_path)) {
    stop("File not found: ", gpkg_path)
  }

  # Resolve the layer to read
  if (is.null(layer)) {
    layers <- st_layers(gpkg_path)$name
    if (length(layers) > 1) {
      message(
        "Multiple layers found (", paste(layers, collapse = ", "),
        "); reading the first one: '", layers[1], "'."
      )
    }
    layer <- layers[1]
  }

  polygons <- st_read(gpkg_path, layer = layer, quiet = TRUE)

  roi_geom <- as_roi_geometry(roi, crs = roi_crs)

  # Align CRS: reproject the ROI to match the polygons
  if (is.na(st_crs(polygons))) {
    stop("The GeoPackage layer has no CRS; cannot compare with the ROI.")
  }
  roi_geom <- st_transform(roi_geom, st_crs(polygons))

  # Filter using the requested spatial predicate
  filter_fun <- switch(
    predicate,
    intersects = st_intersects,
    within = st_within
  )
  selected <- st_filter(polygons, roi_geom, .predicate = filter_fun)

  message(
    nrow(selected), " of ", nrow(polygons),
    " polygons fall inside the ROI (predicate: ", predicate, ")."
  )

  # Optionally clip polygons to the ROI boundary
  if (crop && nrow(selected) > 0) {
    # st_intersection assumes attributes are constant over each geometry
    selected <- suppressWarnings(st_intersection(selected, roi_geom))
    # Keep only polygonal parts; intersections can yield lines/points or
    # GEOMETRYCOLLECTIONs along shared edges.
    selected <- st_collection_extract(selected, "POLYGON", warn = FALSE)
    # Drop any empty geometries left after clipping
    selected <- selected[!st_is_empty(selected), ]
    message(nrow(selected), " polygons remain after cropping to the ROI.")
  }

  if (!is.null(out_path)) {
    st_write(selected, out_path, delete_dsn = TRUE, quiet = TRUE)
    message("Wrote result to: ", out_path)
  }

  selected
}

# --- Example usage ---------------------------------------------------------
# ROI as a bounding box (EPSG:4326):
# roi <- c(lon_min = -50.78, lat_min = -13.39, lon_max = -50.54, lat_max = -13.25)
roi <- c(lat_min = -11.75, lat_max = -11,5, lon_min = -46.0, lon_max = -45.75)

gpkg_file <- "~/sitsdata/inst/extdata/fields_of_the_world/2024_S12W046.gpkg"

gpkg_file_out <- "~/sitsdata/inst/extdata/fields_of_the_world/fow.gpkg"

# Keep only polygons fully contained in the ROI, and save the result:
polys <- extract_polygons_in_roi(
    gpkg_path = gpkg_file, 
    roi = roi,
    predicate = "within", 
    out_path = gpkg_file_out
)
#