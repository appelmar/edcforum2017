# Example script to extract individual Sentinel 2 pixel time series

library(scidb)
library(scidbst)

# connect to the database
scidbconnect(host = "localhost", port = 8083, username = "edc01", 
             password = "edc01", 
             auth_type = "digest", protocol = "https")


# create a reference proxy to the complete dataset
S2.proxy= scidbst("S2_OKAVANGO_T")
S2.proxy

# extract a specific time series
z = pixelts(S2.proxy, c(752002, 7877073))@proxy[] 
z$date = as.Date(tmin(S2.proxy)) + z$t * 10
plot(band1 ~ date, z, type="o", col="blue")
lines(band2 ~ date, z, type="o", col="green")
lines(band3 ~ date, z, type="o", col="red")
lines(band4 ~ date, z, type="o", col = "orange")
plot(x = z$date, y = (z$band4 -z$band3)/(z$band4 + z$band3),type="o", col="red", ylab ="NDVI", ylim=c(-1,1))
