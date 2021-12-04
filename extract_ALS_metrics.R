# Author: Laura Puckett
# 08/26/2020

# *********************************************************************************#
# -----0: Packages
# ********************************************************************************#

list.of.packages <- c("lidR","rgdal", "raster","dplyr", "sp")

new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)>0) install.packages(new.packages, repos='http://cloud.r-project.org')

library(lidR); library(rgdal); library(raster); library(dplyr); library(sp)

# *********************************************************************************#
# -----1: Inputs
# ********************************************************************************#

myMetrics = function(z) {
  metrics = list(
    RH_100_ALS = quantile(z, probs = c(1.00)),
    RH_99_ALS = quantile(z, probs = c(0.99)),
    RH_98_ALS = quantile(z, probs = c(0.98)),
    RH_95_ALS = quantile(z, probs = c(0.95)),
    RH_75_ALS = quantile(z, probs = c(0.75)),
    RH_50_ALS = quantile(z, probs = c(0.50)),
    RH_25_ALS = quantile(z, probs = c(0.25)))
  return(metrics)
}

extract_ALS_metrics = function(sensor, geom_path, output_path, ALS_dir, ctg_path, proj){

  # *********************************************************************************#
  # ----- Get ALS metrics for geometry footprints
  # ********************************************************************************#
  if(file.exists(ctg_path)){
    ctg = readRDS(ctg_path)
  }else{
    ctg = readLAScatalog(ALS_dir)
    saveRDS(object = ctg, file = ctg_path)
  }
  
  geoms_WGS84 = rgdal::readOGR(geom_path)
  geoms = spTransform(geoms_WGS84, proj)
  data = NULL
  
  # clip point cloud to a buffered version of the geometry (keeping edges for ground surface interpolation)
  for(i in 1:nrow(geoms@data)){
    print(i)
    geom = geoms[i,]
    
    las_bufferclip = lidR::clip_roi(las = ctg, geometry = rgeos::gBuffer(geom, 5, byid=T))
    if(nrow(las_bufferclip@data)>0){
      
      # normalize point cloud to the ground
      norm_las = normalize_height(las_bufferclip, knnidw())
      
      ## Summarize point cloud over entire geometry
      norm_las_clip = clip_roi(norm_las, geom)
      if(length(norm_las_clip@data$NumberOfReturns)>0){
        veg = filter_poi(norm_las_clip, Classification %in% c(1L, 3L, 4L, 5L)) # unclassified or vegetation
        las_met = cloud_metrics(las = norm_las_clip,  func = myMetrics(Z)) # previously called lasmetrics()
        geom_data = cbind(geom@data, as.data.frame(las_met))
        
        # can't rbind to NULL, so using this to initialize the dataframe
        if(is.null(data)){
          data = geom_data
        }else{
          data = rbind(data, geom_data)
        }
      }
    }
  }
  # *********************************************************************************#
  # ----- Write Output 
  # ********************************************************************************#
  write.csv(data, output_path)
}
