# directory where files are located
data_dir <- system.file("extdata/Rondonia-20LMR", package = "sitsdata")
# Builds a cube based on existing files
cube_20LMR <- sits_cube(
    source = "AWS",
    collection = "SENTINEL-2-L2A",
    data_dir = data_dir,
    progress = FALSE
)
plot(cube_20LMR, red = "B11", green = "B8A", blue = "B02", date = "2022-07-16")
# segment a cube using SLIC
# Files are available in a local directory
output_dir <-  "~/temp/segments"
segments_20LMR <- sits_segment(
    cube = cube_20LMR,
    output_dir = output_dir,
    seg_fn = sits_slic(
        step = 20,
        compactness = 1,
        dist_fun = "euclidean",
        iter = 20,
        minarea = 20
    ),
    memsize = 16,
    multicores = 4
)
plot(segments_20LMR, red = "B11", green = "B8A", blue = "B02", date = "2022-07-16",
     line_width = 0.2)

library(sitsdata)

rfor_model <- sits_train(samples_deforestation, sits_rfor())

segments_20LMR_probs <- sits_classify(
    data = segments_20LMR,
    ml_model = rfor_model,
    output_dir = output_dir,
    n_sam_pol = 20,
    gpu_memory = 16,
    memsize = 24,
    multicores = 6
)
segments_20LMR_class <- sits_label_classification(
    segments_20LMR_probs,
    output_dir = output_dir,
    memsize = 24,
    multicores = 6
)
labels <- sits_labels(segments_20LMR_class)

expected_ua <- c("Clear_Cut_Bare_Soil" = 0.90,
                 "Clear_Cut_Burned_Area" = 0.80,
                 "Clear_Cut_Vegetation" = 0.75,
                 "Forest" = 0.90,
                 "Mountainside_Forest" = 0.75,
                 "Riparian_Forest" = 0.80,
                 "Seasonally_Flooded" = 0.75,
                 "Water" = 0.90,
                 "Wetland"  = 0.75)

sampling_design <- sits_sampling_design(
    cube = segments_20LMR_class,
    expected_ua = expected_ua)

cube_20LMR_probs <- sits_classify(
    data = cube_20LMR,
    ml_model = rfor_model,
    output_dir = output_dir,
    n_sam_pol = 20,
    gpu_memory = 16,
    memsize = 24,
    multicores = 6
)
cube_20LMR_bayes <- sits_smooth(
    cube = cube_20LMR_probs,
    memsize = 24,
    multicores = 6,
    output_dir = output_dir
)
cube_20LMR_class <- sits_label_classification(
    cube = cube_20LMR_probs,
    output_dir = output_dir
)
sampling_design_2 <- sits_sampling_design(
    cube = cube_20LMR_class,
    expected_ua = expected_ua)

samples_2 <- sits_stratified_sampling(
    cube = cube_20LMR_class,
    sampling_design = sampling_design_2,
    alloc = "alloc_50",
    shp_file = paste0(output_dir,"/samples/samples_raster_20LMR.shp")
)
samples_vec <- sits_stratified_sampling(
    cube = segments_20LMR_class,
    sampling_design = sampling_design,
    alloc = "alloc_50",
    shp_file = paste0(output_dir,"/samples/samples_vector_20LMR.shp")
)
