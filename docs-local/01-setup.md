# Setup {.unnumbered}

## How to use this on-line book {.unnumbered}

This book contains reproducible code that can be run on an R environment. There are three options to setup your working environment:

1. Install R and RStudio and the packages required by `sits`, with specific procedures for each type of operating systems.
2. Use a Docker image provided by the Brazil Data Cube.

## How to install sits using R and RStudio {.unnumbered}

We suggest a staged installation, as follows:

1. Get and install base R from [CRAN](https://cran.r-project.org/).
2. Install RStudio from the [Posit website](https://posit.co/).

Then, chose one of the following options, as decribed below: (a) install `sits` from CRAN; (b) use `docker` containers; (c) use the `conda` environment.

## Installing `sits` from CRAN {.unnumbered}

The Comprehensive R Archive Network (CRAN), a network of servers (also known as mirrors) from around the world that store up-to-date versions of basic code and packages for R. In what follows, we describe how to use CRAN to `sits` on Windows, Linux and MacOS. 

### Installing in Microsoft Windows and MacOS environments{.unnumbered}

Windows and MacOS users are strongly encouraged to install binary packages from CRAN. The `sits` package relies on the `sf` and `terra` packages, which require the GDAL and PROJ libraries. Run RStudio and install binary packages `sf` and `terra`, in this order:


``` r
install.packages("sf")
install.packages("terra")
```

After installing the binaries for `sf` and `terra`, install `sits` as follows;


``` r
install.packages("sits", dependencies = TRUE)
```

To run the examples in the book, please also install `sitsdata` package, which is available from GitHub. It is necessary to use package `devtools` to install `sitsdata`.


``` r
install.packages("devtools")
devtools::install_github("e-sensing/sitsdata")
```

 To install `sits` from source, please install [Rtools](https://cran.r-project.org/bin/windows/Rtools/) for Windows to have access to the compiling environment. For Mac, please follow the instructions available [here](https://mac.r-project.org/tools/).

### Installing in Ubuntu environments{.unnumbered}

For Ubuntu, the first step should be to install the latest version of the GDAL, GEOS, and PROJ4 libraries and binaries. To do so, use the repository `ubuntugis-unstable`, which should be done as follows:

``` sh
sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable
sudo apt-get update
sudo apt-get install libudunits2-dev libgdal-dev libgeos-dev libproj-dev 
sudo apt-get install gdal-bin
sudo apt-get install proj-bin
```
Getting an error while adding this PPA repository could be due to the absence of the package `software-properties-common`. After installing GDAL, GEOS, and PROJ4, please install packages `sf` and `terra`:


``` r
install.packages("sf")
install.packages("terra")
```

Then please proceed to install `sits`, which can be installed as a regular **R** package.


``` r
install.packages("sits", dependencies = TRUE)
```

### Installing in Debian environments{.unnumbered}

For Debian,  use the [rocker geospatial](https://github.com/rocker-org/geospatial) dockerfiles. 

### Installing in Fedora environments

In the case of Fedora, the following command installs all required dependencies:


``` sh
sudo dnf install gdal-devel proj-devel geos-devel sqlite-devel udunits2-devel
```

## Using Docker images {.unnumbered}

If you are familiar with Docker, there are images for `sits` available with RStudio or Jupyter notebook. Such images are provided by the Brazil Data Cube team:

- [Version for R and RStudio](https://hub.docker.com/r/brazildatacube/sits-rstudio).
- [Version for Jupyter Notebooks](https://hub.docker.com/r/brazildatacube/sits-jupyter).

On a Windows or Mac platform, install [Docker](https://docs.docker.com/desktop/install/windows-install/) and then obtain one of the two images listed above from the Brazil Data Cube. Both images contain the full `sits` running environment. When GDAL is running in `docker` containers, please add the security flag `--security-opt seccomp=unconfined` on start. 

## Install `sits` from CONDA {.unnumbered}

Conda is an open-source, cross-platform package manager. It is a convenient way to installl Python and R packages. To use `conda`, first download the software from the [CONDA website](https://conda.io/projects/conda/en/latest/index.html). After installation, use `conda` to install sits from the terminal as follows:


``` bash
# add conda-forge to the download channels 
conda config --add channels conda-forge
conda config --set channel_priority strict
# install sits using conda
conda install conda-forge::r-sits
```

The conda installer will download all packages and libraries required to run `sits`. This is the easiest way to install `sits` on Windows. 


## Accessing the development version {.unnumbered}

The source code repository of `sits` is on [GitHub](https://github.com/e-sensing/sits). There are two versions available on GitHub: `master` and `dev`. The `master` contains the current stable version, which is either the same code available in CRAN or a minor update with bug fixes. To install the `master` version, install `devtools` (if not already available) and do as follows: 


``` r
install.packages("devtools")
devtools::install_github("e-sensing/sits", dependencies = TRUE)
```

To install the `dev` (development) version, which contains the latest updates but might be unstable, install `devtools` (if not already available), and then install `sits` as follows:


``` r
install.packages("devtools")
devtools::install_github("e-sensing/sits@dev", dependencies = TRUE)
```

## Additional requirements {.unnumbered}

To run the examples in the book, please also install `sitsdata` package.


``` r
options(download.file.method = "wget")
devtools::install_github("e-sensing/sitsdata")
```

## Using GPUs with `sits` {.unnumbered}

The `torch` package automatically recognizes if a GPU is available on the machine and uses it for training and classification. There is a significant performance gain when GPUs are used instead of CPUs for deep learning models. There is no need for specific adjustments to `torch` scripts.  To use GPUs, `torch` requires version 11.6 of the CUDA library, which is available for Ubuntu 18.04 and 20.04. Please follow the detailed instructions for setting up `torch` available [here](https://torch.mlverse.org/docs/articles/installation.html).


``` r
install.packages("torch")
```
