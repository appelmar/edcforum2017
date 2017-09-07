# Example script to classify pixels of Sentinel 2
# as permanent water, seasonal water, permanent dry

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
out_array_name = "S2_WATER_CLASSIFIED_ROUT"


# R script that will receive array attributes from the input array as vectors and will be
# executed over all chunks
Rexpr = "cat(paste(Sys.time(), \"Entered R\n\" ), file=\"/tmp/rexec.log\",append=TRUE)
	require(plyr)
	s2.df = data.frame(band1=band1d,band2=band2d,band3=band3d,band4=band4d)
	f <- function(x) {
		return(
			tryCatch({
				rgbmax = apply(cbind(x$band1,x$band2,x$band3), 1, max)
				rgbmin = apply(cbind(x$band1,x$band2,x$band3), 1, min)
				iscloud = ((x$band1 + x$band2 + x$band3)/(3*10000) > 0.4)  
				ndvi = (x$band4 - x$band3)/(x$band4 + x$band3)
				ndvi[iscloud] = NA
				out = NA
				if (sum(!is.na(ndvi)) < 3) out = 0 # too many NAs
				else if (all(ndvi < 0.3 ,na.rm = TRUE)) out = 1 # permanent water, 0.18 seems acceptable threshold
				else if (all(ndvi > 0.1 ,na.rm = TRUE)) out = 2 # permanent dry, 0.18 seems acceptable threshold
				else out = 3 #seasonal water / dry 
				return(c(out = out, cloudy= sum(iscloud)))
			}, error=function(e) {
				return (c(out = NA, cloudy = NA))
		}))}
	s2.classified = ddply(s2.df, c(\"dimy\",\"dimx\"), f)
	list(dimy = as.double(s2.classified$dimy), dimx = as.double(s2.classified$dimx), class = as.double(s2.classified$out), cloudy = as.double(s2.classified$cloudy) )"

# combine R script execution with some postprocessing in an AFL query string
afl.query.R = paste("store(unpack(r_exec(", in_array@proxy@name, ",'output_attrs=4','expr=", Rexpr, "'),i),", out_array_name ,")", sep="")

# derive the schema of the intermediate result
scidb(afl.query.R)

# the following command runs the query above and might takes some time
iquery(afl.query.R) 

# create a proxy object that references the intermediate result, convert
# attribute datatypes and reshape to a two dimensional array (image)
rexec.out = scidb(out_array_name)
rexec.out = scidb::project(transform(rexec.out, y="int64(expr_value_0)", x="int64(expr_value_1)",  class=uint8("expr_value_2"), cloudy=uint8("expr_value_3")), c("y","x","class", "cloudy"))
rexec.out = scidb::redimension(rexec.out, dim = c("y","x"))

# execute the command and store the result as a new array
scidbeval(rexec.out, name="S2_WATER_CLASSIFIED")

# copy the spatial reference of the input array to the result
copySRS(scidb("S2_WATER_CLASSIFIED"), S2.proxy.subset)


# download result as a GeoTIFF image using GDAL
system("gdal_translate -of 'GTiff' 'SCIDB:array=S2_WATER_CLASSIFIED' 'S2_WATER_CLASSIFIED.tif'")

# if needed, plot as an interactive Leaflet map (with reduced resolution) 
library(mapview)
x = stack("S2_WATER_CLASSIFIED.tif")
mapView(subset(x,1), legend=T) +  mapView(subset(x,2), legend=T) 


# scidbrm(c("S2_WATER_CLASSIFIED", "S2_WATER_CLASSIFIED_ROUT"), force=T)