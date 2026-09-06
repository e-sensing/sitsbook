library(sits)
library(sitsdata)
fow_segments <- system.file("extdata/fields_of_the_world/SENTINEL-2_FOW_015009_2024-01-01_2024-12-31_segments_v1.gpkg", package = "sitsdata")

fow <- sf::st_read(fow_segments)

fow_dir <- system.file("extdata/fields_of_the_world/", package = "sitsdata")

data_dir <- system.file("extdata/Bahia-LeJEPA", package = "sitsdata")

emb_cube_015009 <- sits_cube(
    source = "BDC",
    collection = "LANDSAT-OLI-16D",
    data_dir = data_dir,
    multicores = 4
)

plot(emb_cube_015009, red = "EMB05", green = "EMB04", blue = "EMB06")

emb_vector_cube <- sits_cube(
    source = "BDC",
    collection = "LANDSAT-OLI-16D",
    raster_cube = emb_cube_015009,
    vector_dir = fow_dir,
    multicores = 4
)

plot(emb_vector_cube, red = "EMB05", green = "EMB04", blue = "EMB06", seg_color = "white", line_width = 0.6)

samples <- readRDS("~/sitsfm/inst/extdata/cerrado_samples/samples-cer-v14a.rds")

samples_bahia <- sits_sample(samples, frac = 0.1)

samples_bahia <- sits_select(
    samples_bahia, 
    labels != c("Mangrove", "Nat_NonVeg")
)

lejepa_encoder <- readRDS("~/sitsfm/inst/extdata/cerrado_models/ssl_lejepa_tcnn_model_2017_2024.rds")

samples_bahia_emb <- sits_encode(
    samples_bahia,
    lejepa_encoder
)
samples_bahia_emb <- readRDS(system.file("extdata/samples/samples_bahia_emb.rds", package = "sitsdata"))

mlp_model <- sits_train(
    samples_bahia_emb,
    ml_method = sits_mlp()
)
emb_vector_cube_probs <- sits_classify(
    data = emb_vector_cube,
    ml_model = mlp_model,
    roi = fow,
    memsize = 4,
    multicores = 4,
    gpu_memory = 4,
    output_dir = "~/sitsbook/tempdir/R/vec_create"
)

valid <- sits_kfold_validate(
    samples_bahia_emb,
    ml_method = sits_mlp()
)
saveRDS(valid, "~/sitsbook/etc/valid_emb_lejepa_01.rds")
