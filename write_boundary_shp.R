write_boundary_shp = function(xmin, xmax, ymin, ymax, filepath){
  # Author: Laura Puckett. 
  # 11/30/2021
  # Purpose: Write a shapefile from a bounding box coordinates. This assumes coordinates are in WGS84.
  library(sp); library(rgdal); library(rgeos)
  
  coords = c(c(xmin, xmin, xmax, xmax),c(ymin, ymax, ymax, ymin))

  Srl = NULL
  x = c(xmax, xmax, xmin, xmin, xmax)
  y = c(ymin, ymax, ymax, ymin, ymin)
  poly = Polygon(coords = cbind(x, y))
  Polygons_obj = Polygons(srl = c(poly), ID = as.numeric(1))
  Srl = append(Polygons_obj, Srl)
  
  Sr = SpatialPolygons(Srl = Srl, proj4string = sp::CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))
  spdf = SpatialPolygonsDataFrame(Sr = Sr, data = as.data.frame(NA), match.ID = T)
  spdf@data = data.frame("X" = 1)
  writeOGR(obj = spdf,
           dsn = filepath,
           layer = 'boundary',
           overwrite_layer = T,
           driver = 'ESRI Shapefile')
}
