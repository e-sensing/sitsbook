library(sitsdata)
data_dir <- system.file("extdata/Rondonia-20LMR/", package = "sitsdata")
# Read data cube
ro_cube_20LMR <- sits_cube(
    source = "MPC",
    collection = "SENTINEL-2-L2A",
    data_dir = data_dir,
    progress = FALSE
)

samples_defor <- dplyr::filter(samples_deforestation, label != "Mountainside_Forest")


rfor_model <- sits_train(samples_defor, sits_rfor())
ro_cube_20LMR_rfor_probs <- sits_classify(
    ro_cube_20LMR,
    rfor_model,
    output_dir = output_dir,
    multicores = 6,
    memsize = 24,
    version = "rfor-raster"
)
ro_cube_20LMR_rfor_bayes <- sits_smooth(
    ro_cube_20LMR_rfor_probs,
    output_dir = output_dir,
    multicores = 6,
    memsize = 24,
    version = "rfor-raster"
)
ro_cube_20LMR_rfor_class <- sits_label_classification(
    ro_cube_20LMR_rfor_bayes,
    output_dir = output_dir,
    multicores = 6,
    memsize = 24,
    version = "rfor-raster"
)
plot(ro_cube_20LMR_rfor_class,
     tmap_options = list("legend_text_size" = 0.7))

sits_labels(ro_cube_20LMR_rfor_class)

sampling_design <- sits_sampling_design(ro_cube_20LMR_rfor_class,
                                        expected_ua = 0.85)
samples <- sits_stratified_sampling(
    ro_cube_20LMR_rfor_class,
    sampling_design,
    "alloc_50",
    shp_file = paste0(output_dir, "/samples_20LMR.shp")
    )

samples_20LMR <- sits_get_data(
    cube = ro_cube_20LMR,
    samples = samples,
    multicores = 4
)

dem_cube <- sits_cube(
    source = "MPC",
    collection = "COP-DEM-GLO-30",
    tiles = "20LMR"
)

bbox <- sits_bbox(ro_cube_20LMR, as_crs = "EPSG:4326")
roi <- c("xmin" = bbox[["xmin"]], "xmax" = bbox[["xmax"]],
         "ymin" = bbox[["ymin"]], "ymax" = bbox[["ymax"]])
dem_cube_reg <- sits_regularize(
    cube = dem_cube,
    res = 20,
    roi = roi,
    output_dir = output_dir,
    multicores = 4
)

ro_cube_20LMR_dem <- sits_add_base_cube(ro_cube_20LMR, dem_cube_reg)

sits_bands(ro_cube_20LMR_dem)

samples_dem <-

