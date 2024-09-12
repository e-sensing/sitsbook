--- 
title: '**sits**: Satellite Image Time Series Analysis 
    on Earth Observation Data Cubes'
author:
- Gilberto Camara
- Rolf Simoes
- Felipe Souza
- Felipe Menino
- Charlotte Pelletier
- Pedro R. Andrade
- Karine Ferreira
- Gilberto Queiroz
date: "2024-09-12"
output:
  html_document: 
    df_print: tibble
    theme:
        base_font:
          google: "IBM Plex Serif"
        code_font:
          google: "IBM Plex Mono"
  pdf_document: 
    latex_engine: xelatex
    toc: true
    toc_depth: 2 
    df_print: tibble
documentclass: report
link-citations: yes
colorlinks: yes
lot: yes
lof: yes
always_allow_html: true
fontsize: 10,5pt
site: bookdown::bookdown_site
cover-image: images/cover_sits_book.png
bibliography: e-sensing.bib
biblio-style: apalike
csl: ieee.csl
indent: true
description: |
  This book presents  **sits**, an open-source R package for satellite image time series analysis. The package supports the application of machine learning techniques for classifying image time series obtained from Earth observation data cubes.
---



```
## SITS - satellite image time series analysis.
```

```
## Loaded sits v1.5.2.
##         See ?sits for help, citation("sits") for use in publication.
##         Documentation avaliable in https://e-sensing.github.io/sitsbook/.
```

```
## Loaded sitsdata data sets v1.2. Use citation("sitsdata") for use in publication.
```

```
## Loading required package: proxy
```

```
## 
## Attaching package: 'proxy'
```

```
## The following objects are masked from 'package:stats':
## 
##     as.dist, dist
```

```
## The following object is masked from 'package:base':
## 
##     as.matrix
```

```
## Loading required package: dtw
```

```
## Loaded dtw v1.23-1. See ?dtw for help, citation("dtw") for use in publication.
```

```
## dtwclust:
## Setting random number generator to L'Ecuyer-CMRG (see RNGkind()).
## To read the included vignettes type: browseVignettes("dtwclust").
## See news(package = "dtwclust") after package updates.
```




# Preface {-}

<a href="https://github.com/e-sensing/sitsbook"><img class="cover" src="images/cover_sits_book.png" width="326" align="right" alt="Cover image" /></a>

Welcome to the age of big Earth observation data! Petabytes of images are now openly accessible in cloud services. Having free access to massive data sets, we need new methods to measure change on our planet using image data. An essential contribution of big EO data has been to provide access to image time series that capture signals from the same locations continually. Time series are a powerful tool for monitoring change, providing insights and information that single snapshots cannot achieve. Better measurement of natural resources depletion caused by deforestation, forest degradation, and desertification is possible. Experts improve the production of agricultural statistics. Using image time series, analysts can use large data collections to detect subtle changes in ecosystem health and distinguish between various land classes more effectively. Time series analysis is an innovative way to address global challenges like climate change, biodiversity preservation, and sustainable agriculture. 

This book introduces `sits`, an open-source **R** package of big Earth observation data analysis using satellite image time series. Users build regular data cubes from cloud services such as Amazon Web Services, Microsoft Planetary Computer, Copernicus Data Space Ecosystem, NASA Harmonized Landsat-Sentinel, Brazil Data Cube, Swiss Data Cube, Digital Earth Australia, and Digital Earth Africa. The `sits` API includes training sample quality measures, machine learning and deep learning classification algorithms, and Bayesian post-processing methods for smoothing and uncertainty assessment. To evaluate results, `sits` supports best practice accuracy assessments.

## How much R knowledge is required?{-}

The `sits` package is designed for remote sensing experts in the Earth Sciences field who want to use advanced data analysis techniques with basic programming knowledge. The package provides a clear and direct set of functions that are easy to learn and master. Users with a minimal background in R programming can start using `sits` right away. Those familiar with Python or JavaScript may consider lack of **R** knowledge as a barrier to use `sits.` Fear not. Those unfamiliar with **R** can rely on their programming knowledge since **R** scripts in `sits` are easy to follow. Users only need a basic understanding of core concepts of how functions work, which is also required for Python or JavaScript. A minimal investment will be rewarded with access to a package with a rich set of tools.

To quickly master what is needed to run `sits`, please read Parts 1 and 2 of Garrett Golemund's book, [Hands-On Programming with R](https://rstudio-education.github.io/hopr/). Although not needed to run `sits`, your **R** skills will benefit from the book by Hadley Wickham and Gareth Golemund, [R for Data Science (2nd edition)](https://r4ds.hadley.nz/). Important concepts of spatial analysis are presented by Edzer Pebesma and Roger Bivand in their book [Spatial Data Science](https://r-spatial.org/book/).

## Software version described in this book{-}

The version of the `sits` package described in this book is 1.5.1.

## Main reference for `sits` {-}

If you use `sits` in your work, please cite the following paper: 

Rolf Simoes, Gilberto Camara, Gilberto Queiroz, Felipe Souza, Pedro R. Andrade,  Lorena Santos, Alexandre Carvalho, and Karine Ferreira. [Satellite Image Time Series Analysis for Big Earth Observation Data]([https://doi.org/10.3390/rs13132428). Remote Sensing, 13, p. 2428, 2021.

## Intellectual property rights {-}

This book is licensed as [Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)](https://creativecommons.org/licenses/by-nc-sa/4.0/) by Creative Commons. The `sits` package is licensed under the GNU General Public License, version 3.0. 
