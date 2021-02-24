#*********************************************************************************#
# -----0: Packages
# ********************************************************************************#

list.of.packages <- c("lidR","rgdal", "raster","dplyr", "sp")

new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)>0) install.packages(new.packages, repos='http://cloud.r-project.org')

library(lidR); library(rgdal); library(raster); library(dplyr); library(sp)

#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#
args = commandArgs(trailingOnly = T)
i = as.numeric(args[1])
sensor = args[2]
geom_path = args[3]
csv_out_dir = args[4]
ALS_dir = args[5] # '/scratch/pb463/clark_a41/data/ALS/subset_dl/'
ctg_path = args[6] # './ALS/ctg_monsoon.ctg'
cover_path = args[7] # '/scratch/pb463/clark_a41/data/USFS/analytical_CONUS_2016/conus_forestcancover_sierra_box_epsg4326.tif'
group_path = args[8] # '/scratch/pb463/clark_a41/data/USFS/conus_forestgroup/conus_forestgroup_sierra_box_epsg4326.tif'

print("--- Arguments ---")
print(paste0("i: ", i))
print(paste0("sensor: ", sensor))
print(paste0("geom_path: ", geom_path))
print(paste0("csv_out_dir: ", csv_out_dir))
print(paste0("ALS_dir: ", ALS_dir))
print(paste0("ctg_path: ", ctg_path))
print(paste0("cover_path: ", cover_path))
print(paste0("group_path: ", group_path))


#*********************************************************************************#
# -----2: Get ALS metrics for geometry footprints
# ********************************************************************************#
if(file.exists(ctg_path)){
    ctg = readRDS(ctg_path)
}else{
    ctg = readLAScatalog(ALS_dir)
    saveRDS(object = ctg, file = ctg_path)
}

geom_WGS84 = rgdal::readOGR(geom_path)[i,]
geom = spTransform(geom_WGS84, CRSobj = ctg@proj4string)

# clip point cloud to a buffered version of the geometry (keeping edges for ground surface interpolation)
# for some reason, lasclip requires a graphic device (progress bar?). pdf(NULL) if a workaround for monsoon.

pdf(NULL)
las_bufferclip = lidR::lasclip(las = ctg, geometry = rgeos::gBuffer(geom, 5, byid=T)) # called lasclip() in different version
dev.off()

# normalize point cloud to the ground
norm_las = lasnormalize(las_bufferclip, knnidw())

## to summarize over entire geometry, without gridding first...
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

norm_las_clip = lasclip(norm_las, geom)
veg = lasfilter(norm_las_clip, Classification %in% c(1L, 3L, 4L, 5L)) # unclassified or vegetation
las_met = cloud_metrics(norm_las_clip,  ~myMetrics(Z)) # previously called lasmetrics()
geom_data = cbind(geom@data, as.data.frame(las_met))

## alternative method: take average of gridded metrics
chm = grid_canopy(veg, res = 1, algorithm = p2r(0.2))
ALS_rh100_avg_all_gridded = chm[is.na(chm)==F,] %>% mean()
geom_data = cbind(geom_data, "ALS_all_grid" = ALS_rh100_avg_all_gridded)

ALS_rh100_avg_aboveground_gridded = chm[is.na(chm)==F&chm>=0.1,]%>%mean() # only keep values above the ground
geom_data = cbind(geom_data, "ALS_abvg_grid" = ALS_rh100_avg_aboveground_gridded)

## yet another alternate method: use gausian kernel instead of average
if(sensor=="gedi"){
    
    # changing the resolution: a poor work-around to get 25 rows/columns
    chm_for_gauss = grid_canopy(veg, res = 26/25, algorithm = p2r(0.2))

    # will result in a 25x25 squure matrix with gauss weighting. 
    # The corners (whatever is not in the 12.5m diameter footprint is negligible. )I checked. It's something like 10^-31 total
    gauss_kernel <- raster::focalWeight(chm_for_gauss,c(1,12),type='Gauss') 
    
    # be weary of na.rm=T, if there are actual NAs in the footprint, the weighting could be off. 
    chm_gauss = raster::focal(chm_for_gauss,gauss_kernel,pad=T,na.rm=T) 
    
    # the center cell
    ALS_grid_gauss = chm_gauss[13,13]
    geom_data = cbind(geom_data, "ALS_grid_gauss" = ALS_grid_gauss)
}

#*********************************************************************************#
# -----3: Extract ALS, cover, and group  
# ********************************************************************************#

# extract cover value
if(!cover_path == "NA"){
    cover_img = raster(cover_path)
    cover_info = raster::extract(x = cover_img, y = geom_WGS84, weights = T, func = mean, normalizeWeights=T)
    cover_info = sum(cover_info[[1]][,1]*cover_info[[1]][,2])
    geom_data = cbind(geom_data, "cover" = cover_info)

}

# extract forest group values, get percentage of geometry represented by each
if(!group_path == "NA"){
    group_img = raster(group_path)
    group_info  = raster::extract(group_img, geom_WGS84, weights = T) %>%
        as.data.frame() %>%
        group_by(value) %>%
        dplyr::summarize(group_weight = sum(weight)) %>%
        as.data.frame() %>%
        arrange(desc(group_weight)) %>%
        rename(group_code = value) 
    geom_data = cbind(geom_data, group_info[1,]) 
    geom_data = cbind("footprintNum" = i, geom_data)
}


#*********************************************************************************#
# -----4: Write Output 
# ********************************************************************************#
write.csv(geom_data, paste0(csv_out_dir, i, '.csv'))

