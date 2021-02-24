#!/bin/bash
#SBATCH --job-name=geom
#SBATCH --output=./logs/icesat2_csv_to_geometries.log
#SBATCH --time=03:00:00			 
#SBATCH --mem=15G

start='date + %s'
echo "Started at: "
date

module load geos/3.8.1 proj/7.0.0 gdal/3.0.4 R/3.6.2


# inputs: 
#icesat2_csv_path #icesat2_geometry_path

Rscript ./code/icesat2/csv_to_geometries.R $1 $2
echo "Ended at"
date