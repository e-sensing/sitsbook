set.seed(123)

knitr::opts_chunk$set(
    comment = "#>",
    tidy = "styler",
    echo = TRUE,
    cache = TRUE,
    warnings = FALSE,
    message = FALSE,
    dpi = 300,
    fig.show = "hold"
)
# create a temporary working directory for each chapter

# load essentials packages
library(sits)
library(sitsdata)
library(tibble)
library(dtwclust)
library(magrittr)
library(distill)
# verifies if kableExtra package is installed
if (!requireNamespace("kableExtra", quietly = TRUE)) {
    install.packages("kableExtra")
}
library("kableExtra")

show_table <- function(tb) {
    kableExtra::kbl(tb) |>  
        kableExtra::kable_material()
}
if (!knitr:::is_html_output())
{
    options("width" = 56)
    knitr::opts_chunk$set(tidy.opts = list(width.cutoff = 60, indent = 4), 
                          tidy = TRUE)
}


