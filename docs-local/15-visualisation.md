# Data visualisation in `sits` {-}



This Chapter contains a discussion on plotting and visualisation of data cubes in `sits`. 

## Plotting{-}

The `plot()` function produces a graphical display of data cubes, time series, models, and SOM maps. For each type of data, there is a dedicated version of the `plot()` function. See `?plot.sits` for details. Plotting of time series, models and SOM outputs uses the `ggplot2` package; maps are plotted using the `tmap` package. When plotting images and classified maps, users can control the output, which appropriate parameters for each type of image. In this chapter, we provide examples of the options available for plotting different types of maps.

Plotting and visualisation function in `sits` use COG overview if available. COG overviews are reduced-resolution versions of the main image, stored within the same file. Overviews allow for quick rendering at lower zoom levels, improving performance when dealing with large images. Usually, a single GeoTIFF will have many overviews, to match different zoom levels

### Plotting false color maps{-}

We refer to false color maps as images which are plotted on a color scale. Usually these are single bands, indexes such as NDVI or DEMs. For these data sets, the parameters for `plot()` are:
        
- `x`: data cube containing data to be visualised; 
- `band`:  band or index to be plotted;
- `pallete`: color scheme to be used for false color maps, which should be one of the `RColorBrewer` palettes. These palettes have been designed to be effective for map display by Prof Cynthia Brewer as described at the [Brewer website](http://colorbrewer2.org). By default, optical images use the `RdYlGn` scheme, SAR images use `Greys`, and DEM cubes use `Spectral`. 
- `rev`: whether the color palette should be reversed; `TRUE` for DEM cubes, and `FALSE` otherwise.
- `scale`: global scale parameter used by `tmap`. All font sizes, symbol sizes, border widths, and line widths are controlled by this value. Default is 0.75; users should vary this parameter and see the results.
- `first_quantile`: 1st quantile for stretching images (default = 0.05).
- `last_quantile`: last quantile for stretching images (default = 0.95).
- `max_cog_size`: for cloud-oriented geotiff files (COG), sets the maximum number of lines or columns of the COG overview to be used for plotting.   

The following optional parameters are available to allow for detailed control over the plot output:
- `graticules_labels_size`: size of coordinates labels (default = 0.8).
- `legend_title_size`: relative size of legend title (default = 1.0).
- `legend_text_size`: relative size of legend text (default = 1.0).
- `legend_bg_color`: color of legend background (default = "white").
- `legend_bg_alpha`: legend opacity (default = 0.5).
- `legend_position`: where to place the legend (options = "inside" or "outside" with "inside" as default).

The following example shows a plot of an NDVI index of a data cube. This data cube covers part of MGRS tile `20LMR` and contains bands "B02", "B03", "B04", "B05", "B06",  "B07", "B08", "B11", "B12", "B8A", "EVI", "NBR", and "NDVI" for the period 2022-01-05 to 2022-12-23. We will use parameters with other than their defaults.


``` r
# set the directory where the data is
data_dir <- system.file("extdata/Rondonia-20LMR", package = "sitsdata")
# read the data cube
ro_20LMR <- sits_cube(
  source = "MPC",
  collection = "SENTINEL-2-L2A",
  data_dir = data_dir
)
# plot the NDVI for date 2022-08-01
plot(ro_20LMR,
  band = "NDVI",
  date = "2022-08-01",
  palette = "Greens",
  legend_position = "outside",
  scale = 1.0
)
```

<div class="figure" style="text-align: center">
<img src="15-visualisation_files/figure-html/visndvi-1.png" alt="Sentinel-2 NDVI index covering tile 20LMR (&amp;copy; EU Copernicus Sentinel Programme; source: Microsoft modified by authors)." width="100%" />
<p class="caption">(\#fig:visndvi)Sentinel-2 NDVI index covering tile 20LMR (&copy; EU Copernicus Sentinel Programme; source: Microsoft modified by authors).</p>
</div>
### Plotting RGB color composite maps{-}

For RGB color composite maps, the parameters for the `plot` function are:

- `x`: data cube containing data to be visualised;
- `band`:  band or index to be plotted;
- `date`: date to be plotted (must be part of the cube timeline);
- `red`: band or index associated to the red color;
- `green`: band or index associated to the green color;
- `blue`: band or index associated to the blue color;
- `scale`: global scale parameter used by `tmap`. All font sizes, symbol sizes, border widths, and line widths are controlled by this value. Default is 0.75; users should vary this parameter and see the results.
- `first_quantile`: 1st quantile for stretching images (default = 0.05).
- `last_quantile`: last quantile for stretching images (default = 0.95).
- `max_cog_size`: for cloud-oriented geotiff files (COG), sets the maximum number of lines or columns of the COG overview to be used for plotting.  

The optional parameters listed in the previous section are also available. An example follows:


``` r
# plot the NDVI for date 2022-08-01
plot(ro_20LMR,
  red = "B11",
  green = "B8A",
  blue = "B02",
  date = "2022-08-01",
  palette = "Greens",
  scale = 1.0
)
```

<div class="figure" style="text-align: center">
<img src="15-visualisation_files/figure-html/visrgb-1.png" alt="Sentinel-2 color composite covering tile 20LMR (&amp;copy; EU Copernicus Sentinel Programme; source: Microsoft modified by authors)." width="100%" />
<p class="caption">(\#fig:visrgb)Sentinel-2 color composite covering tile 20LMR (&copy; EU Copernicus Sentinel Programme; source: Microsoft modified by authors).</p>
</div>
    
### Plotting classified maps{-}

Classified maps pose an additional challenge for plotting because of the association between labels and colors. In this case, `sits` allows three alternatives:

- Predefined color scheme: `sits` includes some well-established color schemes such as `IBGP`, `UMD`, `ESA_CCI_LC`, and `WORLDCOVER`. There is a predefined color table with associates labels commonly used in LUCC classification to colors. Users can also create their color schemas. Please see section "How Colors Work on `sits` in this chapter.
- legend: in this case, users provide a named vector with labels and colors, as shown in the example below.
- palette: an RColorBrewer categorical palette, which is assigned to labels which are not in the color table. 

The parameters for `plot()` applied to a classified data cube are:

- `x`: data cube containing a classified map;
- `legend`: legend which associated colors to the classes, which is `NULL` by default.
- `palette`: color palette used for undefined colors, which is `Spectral` by default.
- `scale`: global scale parameter used by `tmap`.

The optional parameters listed in the previous section are also available. For an example of plotting a classified data cube with default color scheme, please see the section "Reading classified images as local data cube" in the "Earth observation data cubes" chapter. In what follows we show a similar case using a legend.


``` r
# Create a cube based on a classified image
data_dir <- system.file("extdata/Rondonia-20LLP",
  package = "sitsdata"
)
# Read the classified cube
rondonia_class_cube <- sits_cube(
  source = "AWS",
  collection = "SENTINEL-S2-L2A-COGS",
  bands = "class",
  labels = c(
    "1" = "Burned", "2" = "Cleared",
    "3" = "Degraded", "4" = "Natural_Forest"
  ),
  data_dir = data_dir
)
# Plot the classified cube
plot(rondonia_class_cube,
  legend = c(
    "Burned" = "#a93226",
    "Cleared" = "#f9e79f",
    "Degraded" = "#d4efdf",
    "Natural_Forest" = "#1e8449"
  ),
  scale = 1.0,
  legend_position = "outside"
)
```

<div class="figure" style="text-align: center">
<img src="15-visualisation_files/figure-html/vismap-1.png" alt="Classified data cube for the year 2020/2021 in Rondonia, Brazil (&amp;copy; EU Copernicus Sentinel Programme; source: authors)." width="100%" />
<p class="caption">(\#fig:vismap)Classified data cube for the year 2020/2021 in Rondonia, Brazil (&copy; EU Copernicus Sentinel Programme; source: authors).</p>
</div>


## Visualization of data cubes in interactive maps {.unnumbered}

 Data cubes and samples can also be shown as interactive maps using `sits_view()`. This function creates tiled overlays of different kinds of data cubes, allowing comparison between the original, intermediate and final results. It also includes background maps. The following example creates an interactive map combining the original data cube with the classified map.


``` r
sits_view(rondonia_class_cube,
  legend = c(
    "Burned" = "#a93226",
    "Cleared" = "#f9e79f",
    "Degraded" = "#d4efdf",
    "Natural_Forest" = "#1e8449"
  )
)
```

<img src="./images/view_rondonia_class_cube.png" width="100%" style="display: block; margin: auto;" />

## How colors work in sits{-}

In examples provided in the book, the color legend is taken from a predefined color pallete provided by `sits`. The default color definition file used by `sits` has 220 class names, which can be shown using `sits_colors()`


```
#> [1] "Returning all available colors"
```

```
#> # A tibble: 241 × 2
#>    name                             color  
#>    <chr>                            <chr>  
#>  1 Evergreen_Broadleaf_Forest       #1E8449
#>  2 Evergreen_Broadleaf_Forests      #1E8449
#>  3 Tree_Cover_Broadleaved_Evergreen #1E8449
#>  4 Forest                           #1E8449
#>  5 Forests                          #1E8449
#>  6 Closed_Forest                    #1E8449
#>  7 Closed_Forests                   #1E8449
#>  8 Mountainside_Forest              #229C59
#>  9 Mountainside_Forests             #229C59
#> 10 Open_Forest                      #53A145
#> # ℹ 231 more rows
```

These colors are grouped by typical legends used by the Earth observation community, which include "IGBP", "UMD", "ESA_CCI_LC", "WORLDCOVER", "PRODES", "PRODES_VISUAL", "TERRA_CLASS", "TERRA_CLASS_PT". The following commands shows the colors associated with the IGBP legend [@Herold2009].


``` r
# Display default `sits` colors
sits_colors_show(legend = "IGBP")
```

<div class="figure" style="text-align: center">
<img src="15-visualisation_files/figure-html/unnamed-chunk-4-1.png" alt="Colors used in the sits package to represeny IGBP legend (source: authors)." width="100%" height="100%" />
<p class="caption">(\#fig:unnamed-chunk-4)Colors used in the sits package to represeny IGBP legend (source: authors).</p>
</div>


The default color table can be extended using `sits_colors_set()`. As an example of a user-defined color table, consider a definition that covers level 1 of the Anderson Classification System used in the US National Land Cover Data, obtained by defining a set of colors associated to a new legend. The colors should be defined by HEX values and the color names should consist of a single string; multiple names need to be connected with an underscore("_").

``` r
# Define a color table based on the Anderson Land Classification System
us_nlcd <- tibble::tibble(name = character(), color = character())
us_nlcd <- us_nlcd |>
  tibble::add_row(name = "Urban_Built_Up", color = "#85929E") |>
  tibble::add_row(name = "Agricultural_Land", color = "#F0B27A") |>
  tibble::add_row(name = "Rangeland", color = "#F1C40F") |>
  tibble::add_row(name = "Forest_Land", color = "#27AE60") |>
  tibble::add_row(name = "Water", color = "#2980B9") |>
  tibble::add_row(name = "Wetland", color = "#D4E6F1") |>
  tibble::add_row(name = "Barren_Land", color = "#FDEBD0") |>
  tibble::add_row(name = "Tundra", color = "#EBDEF0") |>
  tibble::add_row(name = "Snow_and_Ice", color = "#F7F9F9")
# Load the color table into `sits`
sits_colors_set(colors = us_nlcd, legend = "US_NLCD")
# Show the new legend
sits_colors_show(legend = "US_NLCD")
```

<div class="figure" style="text-align: center">
<img src="15-visualisation_files/figure-html/colors-1.png" alt="Example of defining colors for the Anderson Land Classification Scheme(source: authors)." width="100%" height="80%" />
<p class="caption">(\#fig:colors)Example of defining colors for the Anderson Land Classification Scheme(source: authors).</p>
</div>

The original default `sits` color table can be restored using `sits_colors_reset()`. 



## Exporting colors to QGIS{-}

To simplify the process of importing your data to QGIS, the color palette used to display classified maps in `sits` can be exported as a QGIS style using `sits_colors_qgis`. The function takes two parameters: (a) `cube`, a classified data cube; and (b) `file`, the file where the QGIS style in XML will be written to. In this case study, we first retrieve and plot a classified data cube and then export the colors to a QGIS XML style.


``` r
# Create a cube based on a classified image
data_dir <- system.file("extdata/Rondonia-Class-2022-Mosaic",
  package = "sitsdata"
)

# labels of the classified image
labels <- c(
  "1" = "Clear_Cut_Bare_Soil",
  "2" = "Clear_Cut_Burned_Area",
  "3" = "Clear_Cut_Vegetation",
  "4" = "Forest",
  "5" = "Mountainside_Forest",
  "6" = "Riparian_Forest",
  "7" = "Seasonally_Flooded",
  "8" = "Water",
  "9" = "Wetland"
)
# read classified data cube
ro_class <- sits_cube(
  source = "MPC",
  collection = "SENTINEL-2-L2A",
  data_dir = data_dir,
  bands = "class",
  labels = labels,
  version = "mosaic"
)
# Plot the classified cube
plot(ro_class, scale = 1.0)
```

<div class="figure" style="text-align: center">
<img src="15-visualisation_files/figure-html/visqgis-1.png" alt="Classified data cube for the year 2022 for Rondonia, Brazil (&amp;copy; EU Copernicus Sentinel Programme; source: authors)." width="100%" />
<p class="caption">(\#fig:visqgis)Classified data cube for the year 2022 for Rondonia, Brazil (&copy; EU Copernicus Sentinel Programme; source: authors).</p>
</div>

The file to be read by QGIS is a TIFF file whose location is informed by the data cube, as follows.


``` r
# Show the location of the classified map
ro_class[["file_info"]][[1]]$path
```

```
#> [1] "/Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/library/sitsdata/extdata/Rondonia-Class-2022-Mosaic/SENTINEL-2_MSI_MOSAIC_2022-01-05_2022-12-23_class_mosaic.tif"
```

The color schema can be exported to QGIS as follows.

``` r
# Export the color schema to QGIS
sits_colors_qgis(ro_class, file = "./tempdir/chp15/qgis_style.xml")
```

