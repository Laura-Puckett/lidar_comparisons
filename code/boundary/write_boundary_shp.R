setwd('//nau.froot.nau.edu/cirrus/scratch/lkp58/icesat_Sierras/boundary/')
library(sp); library(rgdal)

xmin= -120.72
xmax= -120.27
ymin= 38.98
ymax= 39.34

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
plot(spdf)
writeOGR(obj = spdf,
         dsn = './boundary.shp',
         layer = 'boundary',
         overwrite_layer = T,
         driver = 'ESRI Shapefile')
