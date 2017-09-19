# Example script to demonstrate the use of the scidb R package

library(scidb)

# connect to the database
scidbconnect(host = "localhost", port = 8083, username = "edc01", 
             password = "edc01", 
             auth_type = "digest", protocol = "https")

# create a proxy object
x = scidb("S2_OKAVANGO_S")
x
x@name

# select a small subset
x.subset = subarray(x, limits = c(0,0,0,99,99,26), between = FALSE)
x.subset
x.subset@name

# compute new attribute with apply
x.subset.ndvi = transform(x.subset, ndvi = 'double(band4-band3)/double(band4+band3)')$ndvi
x.subset.ndvi
x.subset.ndvi@name

# filter by ndvi values
x.subset.ndvi = subset(x.subset.ndvi, ndvi > 0.3)
x.subset.ndvi
x.subset.ndvi@name

# aggregate over time
x.subset.ndvi.aggregate = aggregate(x.subset.ndvi, by = list("x","y"), FUN="max(ndvi)")
x.subset.ndvi.aggregate
x.subset.ndvi.aggregate@name


# plot -> this will compute everything and download the data to R
image(x.subset.ndvi.aggregate)

# explicitly download the data
y = x.subset.ndvi.aggregate[]
y

# explicitly run the AFL query and store result as a new array
array.name = paste("temp_", paste(sample(letters,16,replace = T), collapse = ""), sep="")
array.name
scidbeval(x.subset.ndvi.aggregate, name = array.name)

scidb(array.name)
image(scidb(array.name))

