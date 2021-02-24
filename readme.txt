#----------#
Purpose: This workflow is intended for comparing gedi, icesat-2, or both against airborne lidar data for an area.
Because Icesat-2 and GEDI can't be compared directly against each other (due to mismatch in size/shape of footprints), 
comparing them against airborne lidar separately is used here to infer how similar they are to each other.

This workflow downloads the icesat-2 data, but assumes that you already have gedi
and airborne lidar downloaded (unless using NEON lidar - there is a script for that)

#----------#

#----------#
Notes about workflow
#----------#
All parameters are set in ./code/main.sh
All other code can be run from that script. 

This workflow should be generalizable to other sites. 

One would need to: 
(1) create a new directory  in ./sites/
(2) select an area with ALS, Icesat-2, and GEDI
(3) Make a shapefile for the boundary (there's an R script in ./code/boundary/ if just using a bounding box)
(4) Download GEDI data as .csv
(5) Download ALS as .laz or .las
(6) If in the US and using conus cover/forest group, clip both conus rasters to the bounding box
(7) Open ./code/main.sh and edit:
    (i) working directory
    (ii) input data locations
    (iii) parameters
(8) Run the code. 
    (i) check jobstats and log files along the way
    (ii) stop to enter array sizes as needed

#----------#
Icesat-2
#----------#

./code/icesat2/nsidc-download_ATL08.003_2020-08-14.py
  Download script, which was generated from https://nsidc.org/data/atl08
  I modified it to take a bounding box string as input
  output: ./data/icesat2/0_dl/

./icesat2/code/hdf5_to_csv.sh
  combined the hdf5 files and converted to csv 
  output: ./data/icesat2/1_icesat2.csv
  
  (kept this step separate from other steps, because I couldn't get a working conda environment that had
  both rhdf5 and the spatial packages that I use)
 
 
./code/icesat2/csv_to_geometries.sh
  made rectangle footprints repensenting the area that each Icesat2 point is aggregated over.
  output:  ./data/icesat2/2_geometries.shp
  
./code/als/extract_ALS_metrics.sh
  executes ./ALS/code/extract_ALS_metrics.R

#----------#
GEDI
#----------#
./code/gedi/csv_to_geometries.R
  takes in a csv with the subset of GEDI L2B
  creates circular 25m diameter geometries cenetered on the X,Y coords
  output : ./data/gedi/1_points.shp
  output : ./data/gedi/2_geometries.shp


./code/als/extract_ALS_metrics.sh
    executes ./ALS/code/extract_ALS_metrics.R

#----------#
ALS
#----------#
./code/als/extract_ALS_metrics.sh
  A general script that computs chm and extract cover and group over the area of each geometry
    clips point cloud to icesat-2 geometry
    calculates als metrics in multiple ways (see script for details)
    extracts canopy cover values by taking a weighted average over the geometry
    extracts group cover (just keeps primary cover. Also reports % of rectangle that was classified as this cover)
    
  It feels silly to have soooo many array members (and thus that many tiny little csv files), but it would take many days to run without parallelizing at all
  Running them 100 at a time using %100 in the array definition keeps them arrays from slowing down each other too much when reading/writing to the same place.  
    

#----------#
Known issues and hard-coded parameters to be aware of
#----------#

I didn't filter Icesat-2 geometries to be completely within the boundary. This would affect a few footprints, at most, out of thousands. 

The icesat-2 geometries are generated using the line between that point and the last point, 
 so it misses any geometries that are the first of their trajectory in the bounding box
Parameters for icesat-2 and gedi footprints (and gedi gaussian kernel) and hard-coded, so you'll have to dig into the code for details on those calculations. 

The ALS gridding is done at 1m res. This may not be appropriate for all ALS datasets. 

#----------#
Future Additions?
#----------#
adapt ./code/als/extract_ALS_metrics.sh to accept a raster for the ALS lidar
automate figure creation
