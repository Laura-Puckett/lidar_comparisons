#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#

working_directory='/scratch/lkp58/lidar_comparisons/'
site_dir=$working_directory'sites/sierras/'

# input data locations
boundary_path=$site_dir'boundary/boundary.shp'
ALS_dir='/scratch/pb463/clark_a41/data/ALS/subset_dl/'
ctg_path='./data/ctg_monsoon.ctg'
gedi_data_path="/scratch/pb463/gedi/GEDI02_A.001/sierra_box_ss_39.333_-120.712_38.984_-120.276_ts_2019.04.18to2019.10.31/2_geocomb/FPgeoloc/sierra_merged_20200819.csv"
cover_path='/scratch/pb463/clark_a41/data/USFS/analytical_CONUS_2016/conus_forestcancover_sierra_box_epsg4326.tif'
group_path='/scratch/pb463/clark_a41/data/USFS/conus_forestgroup/conus_forestgroup_sierra_box_epsg4326.tif'

# parameters
xmin=-120.72
ymin=38.98
xmax=-120.27
ymax=39.34
bbox=$xmin','$ymin','$xmax','$ymax
# read bbox < ./boundary/bbox.txt

# output data locations (these shouldn't need to be updated)
icesat2_dl_dir=$site_dir"data/icesat2/0_dl/"
icesat2_csv_path=$site_dir"data/icesat2/1_icesat2.csv"
icesat2_geom_path=$site_dir"data/icesat2/2_geometries.shp"
icesat2_comp_csv_dir=$site_dir"data/icesat2/3_comparison_csvs/"
icesat2_comp_output_path=$site_dir"data/icesat2/3_comparison.csv"

gedi_points_path=$site_dir"data/gedi/1_center_points.shp"
gedi_geom_path=$site_dir"data/gedi/2_geometries.shp"
gedi_comp_csv_dir=$site_dir"data/gedi/3_comparison_csvs/"
gedi_comp_output_path=$site_dir"data/gedi/3_comparison.csv"

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


DIR=$icesat2_comp_csv_dir
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

DIR=$gedi_comp_csv_dir
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

DIR=$site_dir'logs/icesat2_extract_als_metrics/'
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

DIR=$site_dir'logs/gedi_extract_als_metrics/'
if [ ! -d "$DIR" ]; then
  echo "directory does not exist. Creating directory: "
  echo "${DIR}"
  mkdir -p $DIR
fi

#*********************************************************************************#
# -----3: Icesat2
# ********************************************************************************#
module load anaconda2
conda activate ./conda/python_3.7.0_env/
python ./code/icesat2/download_icesat2_ATL08_v03.py $bbox $icesat2_dl_dir
conda deactivate

# can run the next two steps together
jobid_i1=$(sbatch --parsable --output=$site_dir'logs/hd5f_to_csv.log' ./code/icesat2/hdf5_to_csv.sh $icesat2_dl_dir $icesat2_csv_path $xmin $ymin $xmax $ymax)
jobid_i2=$(sbatch --parsable --dependency=afterok:${jobid_i1} --output=$site_dir'logs/csv_to_geometries.log' ./code/icesat2/csv_to_geometries.sh $icesat2_csv_path $icesat2_geom_path)

# stop and figure out the array, and replace in the next line before running the next two steps together
jobid_i3=$(sbatch --parsable --array=1-16256%100 --time=00:02:00 --output=$site_dir'/logs/icesat2_extract_als_metrics/%a.log' ./code/als/extract_ALS_metrics.sh "icesat2" $icesat2_geom_path $icesat2_comp_csv_dir $ALS_dir $ctg_path $cover_path $group_path)
sbatch --dependency=afterok:${jobid_i3} --output=$site_dir'/logs/icesat2_combine_csvs.log' --time=01:00:00 ./code/general/combineCSVs.sh $icesat2_comp_csv_dir $icesat2_comp_output_path


#*********************************************************************************#
# -----3: GEDI
# ********************************************************************************#

module load geos/3.8.1 proj/7.0.0 gdal/3.0.4 R/3.6.2
Rscript ./code/gedi/csv_to_geometries.R $gedi_data_path $gedi_points_path $boundary_path $gedi_geom_path

# stop and figure out the array, and replace in the next line before running the next two steps together
jobid_g1=$(sbatch --array=1-36092%100 --parsable --output=$site_dir'/logs/gedi_extract_als_metrics/%a.log' ./code/als/extract_ALS_metrics.sh "gedi" $gedi_geom_path $gedi_comp_csv_dir $ALS_dir $ctg_path $cover_path $group_path)
sbatch --dependency=afterok:${jobid_g1} --output=$site_dir'logs/gedi_combine_csvs.log' --time=01:15:00 ./code/general/combineCSVs.sh $gedi_comp_csv_dir $gedi_comp_output_path


#*********************************************************************************#
# -----4: Comparison/Analysis/Whatnot
# ********************************************************************************#

# This part isn't automated
# Open up ./code/general/filter_and_plot_output.Rmd to explore the data and generate figures
