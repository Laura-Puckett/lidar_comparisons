#!/bin/bash
#SBATCH --job-name=ALS   
#SBATCH --output=./logs/extract_ALS_metrics_%a.log
#SBATCH --time=00:04:00				 
#SBATCH --mem=2G

echo "job id:" 
echo $SLURM_JOB_ID

start='date + %s'
echo "Started at: "
date

module load geos/3.8.1 proj/7.0.0 gdal/3.0.4 R/3.6.2

# i sensor geom_path csv_out_dir ALS_dir ctg_path cover_path group_path proj
Rscript ./code/als/extract_ALS_metrics.R $SLURM_ARRAY_TASK_ID $1 $2 $3 $4 $5 $6 $7 

echo "Ended at"
date
