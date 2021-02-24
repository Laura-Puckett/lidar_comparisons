#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#

working_directory='/scratch/lkp58/lidar_comparisons/'
site_dir=$working_directory'sites/NEON_BONA/'

# input data locations
boundary_path=$site_dir'boundary/boundary.shp'
als_dl_dir=$site_dir'data/als/0_dl/'
als_dir=$als_dl_dir'DP1.30003.001/2019/FullSite/D19/2019_BONA_3/L1/DiscreteLidar/ClassifiedPointCloud/' 
ctg_path=$site_dir'data/als/ctg_monsoon.ctg'
# gedi_data_path="/scratch/pb463/gedi/GEDI02_A.001/sierra_box_ss_39.333_-120.712_38.984_-120.276_ts_2019.04.18to2019.10.31/2_geocomb/FPgeoloc/sierra_merged_20200819.csv"
cover_path='NA'
group_path='NA'

# parameters
xmin=-147.67007
ymin=65.12708
xmax=-147.34736
ymax=65.24129
bbox=$xmin','$ymin','$xmax','$ymax
# read bbox < ./boundary/bbox.txt

# output data locations (these shouldn't need to be updated)
icesat2_dl_dir=$site_dir"data/icesat2/0_dl/"
icesat2_csv_path=$site_dir"data/icesat2/1_icesat2.csv"
icesat2_geom_path=$site_dir"data/icesat2/2_geometries.shp"
icesat2_comp_csv_dir=$site_dir"data/icesat2/3_comparison_csvs/" 
icesat2_comp_output_path=$site_dir"data/icesat2/3_comparison.csv"

NEON_site_name='BONA'
NEON_token_path='/home/lkp58/RCode/neon_token.R'

#gedi_points_path="./data/gedi/1_center_points.shp" 
#gedi_geom_path="./data/gedi/2_geometries.shp"
#gedi_comp_csv_dir="./data/gedi/3_comparison_csvs/"
#gedi_comp_output_path="./data/gedi/3_comparison.csv"

#*********************************************************************************#
# -----2: Create subfolders as needed
# ********************************************************************************#

cd $working_directory

DIR=$icesat2_dl_dir
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

#DIR='./data/gedi/'
#if [ ! -d "$DIR" ]; then
#  echo "directory does not exist. Creating directory: "
#  echo "${DIR}"
#  mkdir -p $DIR
#fi

DIR=$icesat2_comp_csv_dir
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

#DIR=$gedi_comp_csv_dir
#if [ ! -d "$DIR" ]; then
#  echo "directory does not exist. Creating directory: "
#  echo "${DIR}"
#  mkdir -p $DIR
#fi

DIR=$site_dir'/logs/icesat2_extract_als_metrics/'
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

#DIR='./logs/gedi_extract_als_metrics/'
#if [ ! -d "$DIR" ]; then
#  echo "directory does not exist. Creating directory: "
#  echo "${DIR}"
#  mkdir -p $DIR
#fi

DIR=$als_dir
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

#*********************************************************************************#
# -----3: Icesat2
# ********************************************************************************#
module load anaconda2
module load geos/3.8.1 proj/7.0.0 gdal/3.0.4 R/3.6.2

conda activate ./conda/python_3.7.0_env/
python ./code/icesat2/download_icesat2_ATL08_v03.py $bbox $icesat2_dl_dir
conda deactivate

Rscript ./code/als/download_NEON_laz.R $NEON_token_path $NEON_site_name 2019 $als_dl_dir

# can run the next two steps together
jobid_i1=$(sbatch --parsable --output=$site_dir'logs/hd5f_to_csv.log' ./code/icesat2/hdf5_to_csv.sh $icesat2_dl_dir $icesat2_csv_path $xmin $ymin $xmax $ymax)
jobid_i2=$(sbatch --parsable --dependency=afterok:${jobid_i1} --time=00:20:00 --output=$site_dir'logs/csv_to_geometries.log' ./code/icesat2/csv_to_geometries.sh $icesat2_csv_path $icesat2_geom_path)



# stop and figure out the array, and replace in the next line before running the next two steps together

jobid_i3=$(sbatch --parsable --array=1-3875%100  --time=00:01:00 --output=$site_dir'/logs/icesat2_extract_als_metrics/%a.log' ./code/als/extract_ALS_metrics.sh "icesat2" $icesat2_geom_path $icesat2_comp_csv_dir $als_dir $ctg_path $cover_path $group_path)
sbatch --dependency=afterok:${jobid_i3} --output=$site_dir'/logs/icesat2_combine_csvs.log' --time=00:05:00 ./code/general/combineCSVs.sh $icesat2_comp_csv_dir $icesat2_comp_output_path


#*********************************************************************************#
# -----3: GEDI
# ********************************************************************************#
# no gedi data for this site

#*********************************************************************************#
# -----4: Comparison/Analysis/Whatnot
# ********************************************************************************#

# This part isn't automated
# Open up ./code/general/filter_and_plot_output.Rmd to explore the data and generate figures
