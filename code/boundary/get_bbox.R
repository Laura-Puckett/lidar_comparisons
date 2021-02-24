library(rgdal)
poly = readOGR('./boundary/boundary.shp')

bbox = raster::extent(poly)
bbox_string  = paste0(bbox@xmin, ",", bbox@ymin,",",  bbox@xmax,",",  bbox@ymax)

fileCon<-file("./boundary/bbox_string.txt")
writeLines(bbox_string, fileCon)
close(fileCon)
