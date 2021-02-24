#!/bin/bash
#SBATCH --job-name=hdf5   
#SBATCH --output=./logs/icesat2_hdf5_to_csv.log
#SBATCH --time=00:30:00				 
#SBATCH --mem=8G

start='date + %s'
echo "Started at: "
date

module load anaconda2
conda activate ./conda/rhdf5_env

# icesat_dir outputpath xmin ymin xmax ymax
Rscript ./code/icesat2/hdf5_to_csv.R $1 $2 $3 $4 $5 $6

echo "Ended at"
date