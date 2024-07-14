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
date: "2024-07-08"
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
## Loaded sits v1.5.1.
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

Petabytes of Earth observation (EO) data are now open and free, making the full extent of image archives available. From these big EO data sets, users can extract satellite image time series, which are sequences of satellite images taken over the same area at different times. These time series can range from days to decades. They are a powerful tool for observing the Earth's surface and its changes over time, enabling insights and analysis that would be difficult or impossible to achieve with single snapshots.   Using image time series, analysts make best use of big Earth observation data collections, capturing subtle changes in ecosystem health and condition and improving the distinction between different land classes.

Satellite image time series are relevant for tracking environmental changes, such as deforestation, forest degradation and desertification. They help to understand the impacts of climate change on natural ecosystems. Time serises can monitor agricultural production and indicate harvesting times. Following natural disasters like floods, earthquakes, and wildfires, image time series can assess damage and monitor recovery.  By monitoring changes in water bodies, they support the management of water resources. 

Satellite image time series offer an unparalleled view of the Earth's surface over time, providing critical data for a wide range of applications that impact society, the environment, and the global economy. Their relevance continues to grow as we face global challenges like climate change, natural resource depletion, and urban expansion.

This book introduces `sits`, an open-source **R** package of big Earth observation data analysis using satellite image time series. Users build regular data cubes from cloud services such as Amazon Web Services, Microsoft Planetary Computer, Copernicus Data Space Ecosyste, NASA Harmonized Landsat-Sentinel, Brazil Data Cube, Swiss Data Cube, Digital Earth Australia and Digital Earth Africa. The `sits` API includes an assessment of training sample quality, machine learning and deep learning classification algorithms, and Bayesian post-processing methods for smoothing and uncertainty assessment. To evaluate results, `sits` supports best practice accuracy assessments.

## Who this book is for {-}

The target audience for `sits` is the community of remote sensing experts with Earth Sciences background who want to use state-of-the-art data analysis methods with minimal investment in programming skills. The package provides a clear and direct set of functions, which are easy to learn and master. Users with a minimal background on **R** programming can start using `sits` right away. Those not yet familiar with **R** only need to learn introductory concepts.  

If you are not an **R** user and would like to quickly master what is needed to run `sits`, please read Parts 1 and 2 of Garrett Golemund's book, [Hands-On Programming with R](https://rstudio-education.github.io/hopr/). If you already are an **R** user and would like to update your skills with the latest trends,  please read the book by Hadley Wickham and Gareth Golemund, [R for Data Science (2nd edition)](https://r4ds.hadley.nz/). Important concepts of spatial analysis are presented by Edzer Pebesma and Roger Bivand in their book [Spatial Data Science](https://r-spatial.org/book/).

## Software version described in this book{-}

The version of the `sits` package described in this book is 1.5.0.

## Main reference for `sits` {-}

If you use `sits` in your work, please cite the following paper: 

Rolf Simoes, Gilberto Camara, Gilberto Queiroz, Felipe Souza, Pedro R. Andrade,  Lorena Santos, Alexandre Carvalho, and Karine Ferreira. [Satellite Image Time Series Analysis for Big Earth Observation Data]([https://doi.org/10.3390/rs13132428). Remote Sensing, 13, p. 2428, 2021.

## Intellectual property rights {-}

This book is licensed as [Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)](https://creativecommons.org/licenses/by-nc-sa/4.0/) by Creative Commons. The `sits` package is licensed under the GNU General Public License, version 3.0. 
