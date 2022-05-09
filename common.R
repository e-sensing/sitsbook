set.seed(123)

knitr::opts_chunk$set(
    comment = "#>",
    echo = TRUE,
    cache = TRUE,
    fig.retina = 0.8, # figures are either vectors or 300 dpi diagrams
    dpi = 300,
    out.width = "70%",
    fig.width = 6,
    fig.align = 'center',
    fig.asp = 0.618,  # 1 / phi
    fig.show = "hold"
)
# create a temporary working directory for each chapter

# load essentials packages
#library(tibble)
library(dtwclust)
library(magrittr)
library(distill)
# verifies if kableExtra package is installed
if (!requireNamespace("kableExtra", quietly = TRUE)) {
    install.packages("kableExtra")
}
library("kableExtra")

show_table <- function(tb) {
    kableExtra::kbl(tb) %>% 
        kableExtra::kable_material()
}
    


