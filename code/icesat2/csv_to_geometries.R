#*********************************************************************************#
# -----0: Packages
# ********************************************************************************#
list.of.packages <- c("sp", "raster","rgdal", "dplyr", "rgeos")

new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)>0) install.packages(new.packages, repos='http://cloud.r-project.org')

library(sp, verbose = FALSE)
library(raster, verbose = FALSE)
library(rgdal, verbose = FALSE)
library(dplyr, verbose = FALSE)
library(rgeos, verbose = FALSE)

#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#
args <- commandArgs(trailingOnly = TRUE)
icesat_path = args[1] # "./data/icesat2/1_icesat2.csv"
geometry_path = args[2] # "./data/icesat2/2_geometries.shp"
proj = sp::CRS("+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +vunits=m +no_defs") # CRS("+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +vunits=m +no_defs") # the crs from ALS dataset

print("---Arguments---")
print(paste0("icesat path: ", icesat_path))
print(paste0("geometry_path: ", geometry_path))
print(paste0("proj: ", proj))


#*********************************************************************************#
# -----2: Create footprint geometries
# ********************************************************************************#
# https://nsidc.org/sites/nsidc.org/files/technical-references/ICESat2_ATL08_data_dict_v003.pdf
# states that lat and long are expressed as the center-most photon, aggregated in 100m chunks

# https://nsidc.org/sites/nsidc.org/files/technical-references/ICESat2_ATL08_ATBD_r003.pdf
# states that the diameter for the 100m aggregated tracks is about 14m


icesat_data = read.csv(icesat_path, stringsAsFactors = FALSE)

coord <- cbind(as.numeric(icesat_data$lon), as.numeric(icesat_data$lat))
icesat_spdf = sp::SpatialPointsDataFrame(coord, icesat_data)
rm(coord)
sp::proj4string(icesat_spdf) = sp::CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")
icesat = spTransform(icesat_spdf, proj)
rm(icesat_data)



footprint_spdf = NULL
print(paste0("total number of points: ", nrow(icesat@data)))

for(footprintNum in 1:nrow(icesat@data)){
  print(footprintNum)
  
  ####------------------------------------------------------------------------####
  #### get data from one icesat-2 point for a single beam
  ####------------------------------------------------------------------------####
  point = sp::SpatialPointsDataFrame(
    coords = cbind(icesat@coords[footprintNum,1], icesat@coords[footprintNum,2]),
    proj4string = proj,
    data = icesat@data[footprintNum,])
  
  ####------------------------------------------------------------------------####
  #### make the geometry for the rectangular footprint of the point
  ####------------------------------------------------------------------------####
  # the idea here is to:
  # (a) use a pair of points to figure out what direction the "track" is,
  # (b) use that to construct a line, 
  # (c) extend the line to the other side of the point of interest,
  # (d) grab a portion of that line that has 50m on either side of the point of interest,
  # (e) buffer that line by the appropriate width to get the rectangle that
  #  the "point" of aggregated data represents
  
  sorted = icesat@data %>% # finding the previous point on the line segment
    filter(filename == point@data$filename & beam == point@data$beam) %>%
    arrange(seg_id_beg)
  
  point_segid_index = which(sorted$seg_id_beg == point@data$seg_id_beg)
  
  if(point_segid_index > 1){
    prev_seg_id = sorted[point_segid_index-1,"seg_id_beg"]
    prev_point_num = which(icesat@data$seg_id_beg == prev_seg_id & icesat@data$filename == point@data$filename & icesat@data$beam == point@data$beam)
    prev_point_coords = cbind(x1 = icesat@coords[prev_point_num,1],x2 = icesat@coords[prev_point_num,2])
    
    # comparing points from two points along the line
    x1 = point@coords[1]
    y1 = point@coords[2]
    x0 = prev_point_coords[1]
    y0 = prev_point_coords[2]
    xdiff = x1-x0
    ydiff = y1-y0
    
    # extending that line to both sides of x0,y0
    xy <- cbind(c(x1-xdiff, x1+xdiff),c(y1-ydiff, y1+ydiff))
    xy.sp = sp::SpatialPoints(xy)
    line <- SpatialLines(list(Lines(Line(xy.sp), ID=footprintNum)))
    line@proj4string = proj
    
    # intersect that with pointBuffer to reatin only the portion of the line that
    # will be used to create the footprint box 
    point_geom  = 
      pointBuffer = gBuffer(point, width = 50, byid = TRUE)
    intsct = gIntersection(line, pointBuffer) # get 50m of line segment on either side of point
    
    # buffer that line to the appropriate width (14m across)
    footprint = gBuffer(intsct, width=(14/2), capStyle = "FLAT")
    footprint = sp::spTransform(footprint, CRSobj = crs("+init=epsg:4326"))

    
    #*********************************************************************************#
    # -----3: Save footprints with data
    # ********************************************************************************#    
    footprint_spdf_tmp = SpatialPolygonsDataFrame(footprint[1],  point@data, match.ID = F)
    
    if(is.null(footprint_spdf)){
      footprint_spdf = footprint_spdf_tmp
    }else{
      footprint_spdf = rbind(footprint_spdf, footprint_spdf_tmp)
    }
  }
}

writeOGR(obj = footprint_spdf, dsn = geometry_path, layer = "icesat2", driver = "ESRI Shapefile", overwrite_layer = T)


