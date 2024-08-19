SITS - Satellite Image Time Series Analysis for Earth Observation Data
Cubes
================

<a href="https://github.com/e-sensing/sitsbook"><img class="cover" src="images/cover_sits_book.png" width="350" align="right" alt="Cover image" /></a>

## Contents of this repository{-}

This repository contains Rmarkdown (.Rmd) files with the text of the book "Satellite Image Time Series Analysis on Earth Observation Data Cubes", which describes the `sits` package and also provides a conceptual background on the subject of big Earth observation data analysis,

## Overview of sits{-}

`sits` is an open source R package for satellite image time series analysis. It enables users to apply machine learning techniques for classifying image time series obtained from earth observation data cubes. The package is available on [github](https://github.com/e-sensing/sits) and provides tools for analysis, visualization, and classification of satellite image time series. Users follow a typical workflow for a pixel-based classification:

1.  Select an analysis-ready data image collection from a cloud provider such as AWS, Microsoft Planetary Computer, Digital Earth Africa, or Brazil Data Cube.
2.  Build a regular data cube using the chosen image collection.
3.  Obtain new bands and indices with operations on data cubes.
4.  Extract time series samples from the data cube to be used as training data.
5.  Perform quality control and filtering on the time series samples.
6.  Train a machine learning model using the time series samples.
7.  Classify the data cube using the model to get class probabilities for each pixel.
8.  Post-process the probability cube to remove outliers.
9.  Produce a labeled map from the post-processed probability cube.
10. Evaluate the accuracy of the classification using best practices.

## Citation{-}

If you use  this book on your work, please use this reference: 

Gilberto Camara, Rolf Simoes, Felipe Souza, Felipe Carlos, Charlotte Pelletier, Pedro R. Andrade, Karine Ferreira, and Gilberto Queiroz. [Satellite Image Time Series Analysis on Earth Observation Data Cubes]([https://doi.org/10.3390/rs13132428). 

## Intellectual property rights {-}

This book is licensed as [Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)](https://creativecommons.org/licenses/by-nc-sa/4.0/) by Creative Commons. 

## How to contribute{-}

We welcome contributions. You may suggest corrections and improvements, and also provide whole chapters with case studies. The `sitsbook` project is released with a [Contributor Code of Conduct](https://github.com/e-sensing/sitsbook/blob/master/CODE_OF_CONDUCT.md).
By contributing to this project, you agree to abide by its terms.