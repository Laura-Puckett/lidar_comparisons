# Author: Laura Puckett
# 11/30/2020
# Purpose: Convert json files of subsetted GEDI footprints to a single shapefile of polygons representing the GEDI footprints

library(sp); library(rgdal)
json_to_geometries = function(json_path, geometry_path, proj){
  points = NULL
  for(file in list.files(json_path, pattern = ".json")){
    points_tmp = readOGR(paste0(json_path, file))
    
    if(is.null(points)){
      points = points_tmp
    }else{
      points = rbind(points, points_tmp)
    }
  }
  
  # transform to projected coordinate system for buffering
  points = spTransform(points, proj)
  # create 12.5m radius geometries from gedi footprint center points
  geoms = rgeos::gBuffer(points, width = 12.5, byid = T) %>%
  # convert back to WGS84
  spTransform(sp::CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"))
  writeOGR(geoms, layer = "geometry", geometry_path, driver = "ESRI Shapefile", overwrite_layer = T)
}

