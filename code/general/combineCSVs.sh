#!/bin/bash
#SBATCH --job-name=combineOutput               
#SBATCH --time=00:30:00				 
#SBATCH --mem=2G

module load R/3.6.2
Rscript ./code/general/combineCSVs.R $1 $2
