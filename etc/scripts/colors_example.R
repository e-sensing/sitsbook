def_legend <- c(
    "No_Samples" = "#808080",
    "Bosque" = "#4daf4a",
    "Pasto" = "#ffff33",
    "Permanente" = "#f781bf",
    "Rastrojo" = "#a65628",
    "Rio" = "#1f78b4",
    "Semipermanente" = "#a6cee3",
    "Transitorio" = "#984ea3",
    "Urbano"= "#e41a1c"
)

dane <- tibble::tibble(name = character(), color = character())
dane <- dane |>
    tibble::add_row(name = "No_Samples", color = "#808080") |>
    tibble::add_row(name = "Bosque", color = "#4daf4a") |>
    tibble::add_row(name = "Pasto", color = "#ffff33") |>
    tibble::add_row(name = "Permanente", color = "#f781bf") |>
    tibble::add_row(name = "Rastrojo", color = "#a65628") |>
    tibble::add_row(name = "Rio", color = "#1f78b4") |>
    tibble::add_row(name = "Semipermanente", color = "#a6cee3") |>
    tibble::add_row(name = "Transitorio", color = "#984ea3") |>
    tibble::add_row(name = "Urbano", color = "#e41a1c")
# Load the color table into `sits`
sits_colors_set(colors = dane, legend = "DANE")
sits_colors_show(legend = "DANE")
