# Example script to average Sentinel 2
# images over time with SciDB and R

library(scidb)
library(scidbst)

# connect to the database
scidbconnect(host = "localhost", port = 8083, username = "edc01", 
             password = "edc01", 
             auth_type = "digest", protocol = "https")


# create a reference proxy to the complete dataset
S2.proxy= scidbst("S2_OKAVANGO_T")
S2.proxy

# select a spatial subregion
S2.proxy.subset = crop(S2.proxy, extent(753231,766100,7870784,7878355))

# average over time for all bands
S2.proxy.subset.avg = aggregate.t(S2.proxy.subset, FUN="avg(band1),avg(band2),avg(band3),avg(band4)")

# execute query and store result as a new array
scidbsteval(S2.proxy.subset.avg, name="S2_AVG_SUBSET")


# download result as a GeoTIFF image using GDAL
Sys.setenv(SCIDB4GDAL_HOST="https://localhost",  SCIDB4GDAL_PORT=8083, SCIDB4GDAL_USER="edc01", SCIDB4GDAL_PASSWD="edc01")
system("gdal_translate -of 'GTiff' 'SCIDB:array=S2_AVG_SUBSET' 'S2_AVG_SUBSET.tif'")


# if needed, plot as an interactive Leaflet map (with reduced resolution) 
library(mapview)
S2.ndvi.range = stack("S2_AVG_SUBSET.tif")
viewRGB(S2.ndvi.range, 3,2,1)


# delete created array
# scidbrm(c("S2_AVG_SUBSET"), force=T)
