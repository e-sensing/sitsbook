library(sitsdata)
library(sits)
sits_bands(samples_deforestation)
data_dir <- "/Users/gilberto/rondonia20LMR/inst/extdata/images/"

cube_20LMR <- sits_cube(
    source = "MPC",
    collection = "SENTINEL-2-L2A",
    bands = c("B02", "B8A", "B11", "NDVI", "EVI", "NBR"),
    data_dir = data_dir
)

files <- list.files(data_dir)

files
output_dir <- "/Users/gilberto/sitsdata/inst/extdata/Rondonia-20LMR/"

new_files <- purrr::map_chr(files, function(file){
    old_file <- paste0(data_dir, file)
    new_file <- paste0(output_dir, file)
    gdalUtilities::gdal_translate(
        src_dataset = old_file,
        dst_dataset = new_file,
        srcwin = c(1500, 1500, 1200, 1200),
        co = c("COMPRESS=LZW", "PREDICTOR=2",
               "BIGTIFF=YES", "TILED=YES",
               "BLOCKXSIZE=512", "BLOCKYSIZE=512")
    )
    return(new_file)
})

rfor1_val <- sits_kfold_validate(samples_deforestation_rondonia_11classes)

data_dir <- system.file("extdata/Rondonia-20LMR", package = "sitsdata")
# Builds a cube based on existing files
cube_20LMR <- sits_cube(
    source = "AWS",
    collection = "SENTINEL-2-L2A",
    data_dir = data_dir
)
plot(cube_20LMR, red = "B11", green = "B8A", blue = "B02", date = "2022-07-16")

segments_20LMR <- sits_segment(
    cube = cube_20LMR,
    output_dir = "./tempdir/chp14",
    seg_fn = sits_slic(
        step = 20,
        compactness = 1,
        dist_fun = "euclidean",
        iter = 20,
        minarea = 20
    )
)
plot(segments_20LMR, red = "B11", green = "B8A", blue = "B02", 
     date = "2022-07-16")

sits_bands(samples_deforestation)

svm_model <- sits_train(samples_deforestation, sits_svm())

segments_20LMR_probs_svm <- sits_classify(
    data = segments_20LMR,
    ml_model = svm_model,
    output_dir = "./tempdir/chp14",
    n_sam_pol = 40,
    gpu_memory = 16,
    memsize = 24,
    multicores = 6,
    version = "svm-segments"
)
