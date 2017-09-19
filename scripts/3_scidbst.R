# Example script to demonstrate the use of the scidbst R package

library(scidb)
library(scidbst)

# connect to the database
scidbconnect(host = "localhost", port = 8083, username = "edc01", 
             password = "edc01", 
             auth_type = "digest", protocol = "https")

# create a proxy object
x = scidbst("S2_OKAVANGO_S")
x
x@proxy
x@proxy@name

# select a small subset



x.subset = crop(x, extent(758231,761100,7873784,7875355), between = TRUE)
x.subset

# compute new attribute with apply
x.subset.ndvi = project(transform(x.subset, ndvi = 'double(band4-band3)/double(band4+band3)'), c("ndvi"))
x.subset.ndvi


# filter by ndvi values
x.subset.ndvi = subset(x.subset.ndvi, ndvi > 0.3)
x.subset.ndvi


# aggregate over time
x.subset.ndvi.aggregate = aggregate.t(x.subset.ndvi,  FUN="max(ndvi)")
x.subset.ndvi.aggregate

#  this will compute everything and download the data to R as a RasterBrick
y = as(x.subset.ndvi.aggregate,"RasterBrick" )
image(y)

# add to an interactive map
library(mapview)
mapView(y[[1]])



# explicitly run the AFL query and store result as a new array (with spatial reference)
array.name = paste("temp_", paste(sample(letters,16,replace = T), collapse = ""), sep="")
array.name
scidbsteval(x.subset.ndvi.aggregate, name = array.name)

scidbst(array.name)


