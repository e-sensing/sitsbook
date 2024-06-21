# Prueba segmentacion en sits
# Object-based time series image analysis (OBIA)

# Estefania Pizarro Arias (eapizarro@ine.gob.cl)
# Alberto Jopia Tello (anjopiat@ine.gob.cl)
# Instituto Nacional de Estadisticas (INE, Chile)


# Librerias ---------------------------------------------------------------

library(sf)
library(sits)


# ROI ---------------------------------------------------------------------
# Región de interes (San Javier, comuna Región del Maule)
roi_snjav <- st_read("/data/in/Roi/Maule/San_Javier.shp")


# Creacion de cubos -------------------------------------------------------

# Sentinel-2
bands_s2    <- c("B02","B03","B04","B05","B06","B07","B08","B8A","B11","B12","CLOUD")

cube_mau_s2 <- sits_cube(
  source         = "MPC",               # Servidores
  collection     = "SENTINEL-2-L2A",    # Coleccion solicitada
  tiles          = "19HBA",             # Se puede solicitar uno o varios tiles
  #roi           = roi_linares,         # Region de interes (pueden pedirse tiles o una region)
  bands          = bands_s2,            # Banda o bandas solicitadas
  start_date     = "2020-05-01",        # Fecha inicio
  end_date       = "2021-06-07"         # Fecha termino
)

# Sentinel-1
cube_mau_s1 <- sits_cube(
  source         = "MPC",
  collection     = "SENTINEL-1-RTC",
  bands          = c("VV", "VH"),
  orbit          = "descending",
  roi            = roi_snjav,
  start_date     = "2020-04-29",
  end_date       = "2021-06-07"   
)

# DEM cube
dem_cube <- sits_cube(
  source         = "MPC",             # Servidores
  collection     = "COP-DEM-GLO-30",  # Coleccion solicitada
  tiles          = "19HBA",           # Se puede solicitar uno o varios tiles
  #roi = roi_maule,                   # Region de interes (pueden pedirse tiles o una region)
  bands          = "ELEVATION"        # Banda o bandas solicitadas
)


# Regularizacion de los cubos ---------------------------------------------
#(REGULARIZACION PARA LOS TRES CUBOS EN BASE A REGION DE INTERES)

# Regularizar S2
reg_cube_s2 <- sits_regularize(
  cube       = cube_mau_s2,                     # Cubo de datos a ser regularizado
  period     = "P16D",                          # Intervalo de tiempo en el cual queda el cubo
  output_dir = "/data/out/prueba_segmento/",    
  res        = 10,                              # resolucion del pixel del cubo regularizado
  roi        = roi_snjav,                       # region de interes
  multicores = 16  )                          

# generar indices para cubo sentinel-2
reg_cube_s2 <- sits_apply(reg_cube_s2,
                            NDVI = ((B08 - B04) / (B08 + B04)),
                            memsize = 64,
                            multicores = 16,
                            output_dir = "/data/out/prueba_segmento/s2/",
                            progress = T)

# Calculate NDWI using bands B03 and B08
reg_cube_s2 <- sits_apply(reg_cube_s2,
                            NDWI = ((B03 - B08)/(B03 + B08)),
                            output_dir = "/data/out/prueba_segmento/s2/",
                            memsize = 64,
                            multicores  = 16,
                            progress = T)
 
# Calculate PSRI using bands B02, B04 and B06
reg_cube_s2 <- sits_apply(reg_cube_s2,
                            PSRI = ((B04 - B02)/B06),
                            output_dir = "/data/out/prueba_segmento/s2/",
                            memsize = 64,
                            multicores  = 16,
                            progress = T)


# Regularizar S1
reg_cube_s1 <- sits_regularize(
  cube       = cube_mau_s1,                       # Cubo de datos a ser regularizado
  period     = "P16D",                            # Intervalo de tiempo en el cual queda el cubo
  output_dir = "/data/out/prueba_segmento/s1/",        
  res        = 10,                                # resolucion del pixel del cubo regularizado
  roi        = roi_snjav,                         # region de interes
  multicores = 16                                 # nucleos utilizados
)

# Regularizar cubo DEM
reg_cube_dem <- sits_regularize(
  cube        = dem_cube,                     # Cubo de datos a ser regularizado
  output_dir  = "/data/out/prueba_segmento/dem/",       
  res         = 10,                           # resolucion del pixel del cubo regularizado
  roi         = roi_snjav,                    # region de interes
  multicores  = 16,
  memsize     = 48)

# rm(reg_cube_s2, reg_cube_s1, reg_cube_dem)


# Cargar cubos locales ----------------------------------------------------

# Sentinel-2
s2_local <- sits_cube(
   source         = "MPC",               
   collection     = "SENTINEL-2-L2A",    
   data_dir       = "/data/out/prueba_segmento/s2/")
 
# Visualizacion
plot(s2_local, red = "B08", green = "B04", blue = "B03",
     dates = "2021-01-14") # El cubo generado corta por los limites maximos del ROI, dejando un corte cuadrado
 
s2_local <- sits_select(data = s2_local, 
                        bands = c("NDVI","PSRI","NDWI", "B11","B12","B06","B05","B07")) 

 
# Sentinel-1
s1_local <- sits_cube(
  source         = "MPC",               # Servidores
  collection     = "SENTINEL-1-RTC",    # Coleccion solicitada
  data_dir       = "/data/out/prueba_segmento/s1/"
  #tiles = "19HBA"
)

# Visualizacion
plot(s1_local, band = "VV",
     dates = "2021-01-10",palette = "Greys") # El cubo generado enmascara el ROI, dejando la forma del archivo vectorial

s1_local <- sits_select(data = s1_local, bands = c("VV")) 


# Dem
dem_local <- sits_cube(
  source         = "MPC",               # Servidores
  collection     = "COP-DEM-GLO-30",    # Coleccion solicitada
  data_dir       = "/data/out/prueba_segmento/dem/")

# Visualizacion
plot(dem_local, band = "ELEVATION", palette = "Blues") # El cubo generado enmascara el ROI, dejando la forma del archivo vectorial



cube_merge <- sits_merge(s2_local, s1_local)



 # segment a cube using SLIC
 segments <- sits_segment(
   cube = s2_local,
   output_dir = "/data/out/prueba_segmento/segmentos/",
   multicores = 8,              # nucleos
   memsize = 32,                 # ram
   seg_fn = sits_slic(
     avg_fun = "median",         # Función para calcular el valor de cada superpixel
     step = 20,                  # distancia, medida en número de celdas, entre los centros de los superpíxeles iniciales
     compactness = 1,            # Valor que controla la densidad de los superpíxeles. valores más grandes hacen que los grupos sean más compactos.
     dist_fun = "euclidean",     # metrica utilizada para medir la distancia entre valores
     iter = 10,                  # numero de iteraciones
     minarea = 10                # Tamaño mínimo de los superpíxeles de salida (medido en número de celdas). minimo es 10
   ),
   version = "v7"                # version generada
 )

 sits_timeline(segments)
 
 plot(segments,
           red = "B11", green = "B05", blue = "B06",
           dates = "2021-03-19")
 
 sits_view(segments,
           red = "B11", green = "B05", blue = "B06",
           dates = "2021-03-19")


 sits_view(segments,
           band = "NDVI") 
 