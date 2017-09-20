# Example script to ingest Sentinel2 scenes to SciDB, requires GDAL 
# installation with SciDB driver (https://github.com/appelmar/scidb4geo)

#install.packages("gdalUtils")
library(gdalUtils)

S2_ZIP_DIR = "/opt/data/S2" # this is the folder where zip files from the Copernicus Open Access Hub are stored
S2_TEMP_DIR = "/tmp/S2" # this is the folder where zip files will be extracted



#######################################################
# 1. unzip all available scenes 
#######################################################

unlink(S2_TEMP_DIR, recursive = TRUE, force = TRUE)
S2.zip = list.files(path = S2_ZIP_DIR, pattern=".zip", full.names = T) # find available scenes
cat(paste("Found", length(S2.zip), "Sentinel2 scenes.\n"))

for (i in 1:length(S2.zip)) {
  cat(paste("(",i,"/" , length(S2.zip), ") unzipping '", S2.zip[i], "'...\n", sep=""))
  res = unzip(S2.zip[i], exdir = S2_TEMP_DIR, overwrite = TRUE)
}



#######################################################
# 2. collect some metadata about the scenes
#######################################################

scenes = data.frame(dir = list.dirs(path = S2_TEMP_DIR,recursive = FALSE, full.names = T), stringsAsFactors = FALSE)
scenes$name = tools::file_path_sans_ext(basename(scenes$dir))
scenes$xml = paste(scenes$dir, "MTD_MSIL1C.xml", sep="/") # XML file that can be read by GDAL
scenes$gdaldataset = paste("SENTINEL2_L1C:", scenes$xml, ":10m:EPSG_32734", sep="") # only use bands with 10m spatial resolution
scenes$date = as.Date(substr(scenes$name, 12, 19),format = "%Y%m%d") # extract date from scene identifier
scenes = scenes[order(scenes$date),] # order by date

diff(scenes$date)
gdalinfo(scenes$gdaldataset[1])




#######################################################
# 3. ingest scenes to SciDB
#######################################################

SCIDB_HOST = "https://localhost"
SCIDB_PORT = 8083
SCIDB_USER = "edc01"
SCIDB_PW   = "edc01"
SCIDB_ARRAYNAME = "S2_OKAVANGO_S"

BBOX = "699960 7790200 809760 7900000" # xmin, ymin, xmax, ymax
SRS = "EPSG:32734"

# We don't want to pass this information in every single gdal_translate call und thus set it as environment variables
Sys.setenv(SCIDB4GDAL_HOST=SCIDB_HOST,  SCIDB4GDAL_PORT=SCIDB_PORT, SCIDB4GDAL_USER=SCIDB_USER, SCIDB4GDAL_PASSWD=SCIDB_PW)

i = 1
# call gdal_translate with output format "SciDB" and date time create options 
# the first scene will create a new array and additionally requires to set the overall bounding box
res = gdal_translate(src_dataset = scenes$gdaldataset[i],
                    dst_dataset = paste("SCIDB:array=", SCIDB_ARRAYNAME, sep=""),
                    of = "SciDB", co = list(paste("t=",format(scenes$date[i],"%Y-%m-%d"),sep=""), "dt=P10D", paste("bbox=",BBOX,sep=""), paste("srs=", SRS, sep=""),  "type=STS"))

i = i + 1
while (i <= nrow(scenes)) {
  # iteratively add scenes to the array
  res = gdal_translate(src_dataset = scenes$gdaldataset[i],
                       dst_dataset = paste("SCIDB:array=", SCIDB_ARRAYNAME, sep=""),
                       of = "SciDB", co = list(paste("t=",format(scenes$date[i],"%Y-%m-%d"),sep=""), "dt=P10D", "type=ST"))
  i = i + 1
}

# results in a single three-dimensional SciDB array

