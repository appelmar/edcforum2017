# Example script to derive a most green image of Sentinel 2
# image time series with SciDB and R

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


# add dimension values as attributes and remove unneeded attributes
in_array = transform(S2.proxy.subset, dimx = "double(x)", dimy = "double(y)", band1d = "double(band1)",  band2d = "double(band2)",  band3d = "double(band3)", band4d = "double(band4)")
in_array = project(in_array,c("dimx", "dimy", "band1d", "band2d", "band3d", "band4d"))


# specify the name for an intermediate result array, which comes from
# running an R script (see below) over all data chunks within the database
out_array_name = "S2_MAXDVI_ROUT"

# R script that will receive array attributes from the input array as vectors and will be
# executed over all chunks
Rexpr = "require(plyr)
s2.df = data.frame(band1=band1d,band2=band2d,band3=band3d,band4=band4d)
f <- function(x) {
ndvi = (x$band4 - x$band3)/(x$band4 + x$band3)
idx = which.max(ndvi)
return(c(band1 = x$band1[idx], band2 = x$band2[idx], band3 = x$band3[idx], band4 = x$band4[idx]))
}
s2.greenest = ddply(s2.df, c(\"dimy\",\"dimx\"), f)
list(dimy = as.double(s2.greenest$dimy), 
dimx = as.double(s2.greenest$dimx),
band1 = as.double(s2.greenest$band1), 
band2 = as.double(s2.greenest$band2), 
band3 = as.double(s2.greenest$band3), 
band4 = as.double(s2.greenest$band4) )"

# combine R script execution with some postprocessing in an AFL query string
afl.query.R = paste("store(unpack(r_exec(", in_array@proxy@name, ",'output_attrs=6','expr=", Rexpr, "'),i),", out_array_name ,")", sep="")

# derive the schema of the intermediate result
scidb(afl.query.R)

# the following command runs the query above and might takes some time
iquery(afl.query.R) 

# create a proxy object that references the intermediate result, convert
# attribute datatypes and reshape to a two dimensional array (image)
rexec.out = scidb(out_array_name)
rexec.out = scidb::project(transform(rexec.out, y="int64(expr_value_0)", 
                                     x="int64(expr_value_1)",  
                                     band1="uint16(expr_value_2)",
                                     band2="uint16(expr_value_3)",  
                                     band3="uint16(expr_value_4)",  
                                     band4="uint16(expr_value_5)"), c("y","x","band1", "band2","band3", "band4"))
rexec.out = scidb::redimension(rexec.out, dim = c("y","x"))

# execute the command and store the result as a new array
scidbeval(rexec.out, name="S2_MAXDVI")

# copy the spatial reference of the input array to the result
copySRS(scidb("S2_MAXDVI"), S2.proxy.subset)

# download result
Sys.setenv(SCIDB4GDAL_HOST="https://localhost",  SCIDB4GDAL_PORT=8083, SCIDB4GDAL_USER="edc01", SCIDB4GDAL_PASSWD="edc01")
system("gdal_translate -of 'GTiff' 'SCIDB:array=S2_MAXDVI' 'S2_MAXDVI.tif'")

# if needed, plot as an interactive Leaflet map (with reduced resolution) 
library(mapview)
S2.maxndvi = stack("S2_MAXDVI.tif")
viewRGB(S2.maxndvi, 3,2,1)


# delete created arrays
# scidbrm(c("S2_MAXDVI_ROUT", "S2_MAXDVI"), force=T)

