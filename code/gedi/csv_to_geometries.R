#*********************************************************************************#
# -----0: Packages
# ********************************************************************************#
list.of.packages <- c("rgeos","rgdal", "raster","dplyr", "sp")

new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)>0) install.packages(new.packages, repos='http://cloud.r-project.org')

library(sp, verbose = F); library(dplyr, verbose = F); library(rgdal, verbose = F); library(rgeos, verbose = F); library(raster, verbose = F)

#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#
args = commandArgs(trailingOnly = T)
data_path = args[1]
points_path = args[2]
boundary_path = args[3]
geometries_path = args[4]
proj = CRS(args[5])
radius = 12.5

print("--- Arguments ---")
print(paste0("1. data_path: ", data_path))
print(paste0("2. points_path: ", points_path))
print(paste0("3. boundary_path: ", boundary_path))
print(paste0("4. geometries_path: ", geometries_path))
print(paste0("5. proj: ", proj))

#*********************************************************************************#
# -----2: Read data, transform, clip to boundary
# ********************************************************************************#

gedi_data = read.csv(data_path, stringsAsFactors = F)
coord <- cbind(gedi_data$X, gedi_data$Y)
gedi_points = sp::SpatialPointsDataFrame(coord, gedi_data)
rm(coord); rm(gedi_data)
sp::proj4string(gedi_points) = sp::CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")

# only include footprints that are fully within boundary (so clip to smaller boundary)
boundary = readOGR(boundary_path)
boundary = spTransform(boundary, proj)
boundary_smaller = gBuffer(boundary, width=-1*radius)
gedi_points = spTransform(gedi_points, proj)
gedi_points = raster::intersect(gedi_points, boundary_smaller)

#*********************************************************************************#
# -----3: Create footprint geometries
# ********************************************************************************#

# 25m average diameter for footprints: https://gedi.umd.edu/instrument/specifications/#:~:text=GEDI+contains+three+Nd%3AYAG,averaging+25+m+in+diameter
gedi_footprints = gBuffer(gedi_points, width = radius, byid = T)

#*********************************************************************************#
# -----4: Save points and geometries 
# ********************************************************************************#  

# transform back to WGS84
gedi_points = spTransform(gedi_points, CRSobj = crs("+init=epsg:4326"))
gedi_footprints = spTransform(gedi_footprints, CRSobj = crs("+init=epsg:4326"))

writeOGR(obj = gedi_points, dsn = points_path, layer = "gedi", driver = "ESRI Shapefile", overwrite_layer = T)
writeOGR(obj = gedi_footprints, dsn = geometries_path, layer = "gedi", driver = "ESRI Shapefile", overwrite_layer = T)



