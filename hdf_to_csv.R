# Author: Laura Puckett
# 08/26/2020
# Purpose: Read hdf files of icesat-2 data, extract canopy data with a given bounding box, and output the resulting dataframe as a csv.

hdf_to_csv = function(icesat_dir, output_path, ymax, xmin, ymin, xmax){
  
  # *********************************************************************************#
  # -----0. Packages
  # ********************************************************************************#
  if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
  if (!requireNamespace("rhdf5", quietly = TRUE))
    BiocManager::install("rhdf5")
  library(rhdf5)
  
  # *********************************************************************************#
  # -----1: Body
  # ********************************************************************************#
  icesat_files = list.files(icesat_dir, pattern = "h5", recursive = TRUE)
  # print(c("icesat files: ", icesat_files))
  
  df = NULL
  count=0
  for(beam in c("1l","1r","2l","2r","3l","3r")){
    for (filename in icesat_files){
      count=count+1
      print(count/(length(icesat_files)*6))
      # print(rhdf5::h5ls(paste0(icesat_dir, "/", filename))) # View data structure
      tmp = try(rhdf5::h5read(file = paste0(icesat_dir, filename), paste0("/gt", beam, "/")), silent = TRUE)
      # in some .h5 files, there isn't info for every beam
      if(class(tmp) == "try-error"){
        print(paste0("Information from file ", filename, "is missing for beam ", beam))
      }else if(is.null(tmp$land_segments)==FALSE){
        df.tmp = NULL
        
        # extract metadata
        df.tmp = cbind(df.tmp, "seg_id_beg" = tmp$land_segments$segment_id_beg)
        df.tmp = cbind(df.tmp, "seg_id_end" = tmp$land_segments$segment_id_end)
        df.tmp = cbind(df.tmp, "lat" = as.numeric(tmp$land_segments$latitude))
        df.tmp = cbind(df.tmp, "lon" = as.numeric(tmp$land_segments$longitude))
        df.tmp = cbind(df.tmp, "h_te_mean" = as.numeric(tmp$land_segments$h_te_mean))
        df.tmp = cbind(df.tmp, "n_te_photons" = as.numeric(tmp$land_segments$n_te_photons))
        df.tmp = cbind(df.tmp, "h_te_uncertainty" = as.numeric(tmp$land_segments$h_te_uncertainty))
        df.tmp = cbind(df.tmp, "terrain_slope" = as.numeric(tmp$land_segments$terrain_slope))
        df.tmp = cbind(df.tmp, "night_flag" = tmp$land_segments$night_flag)
        df.tmp = cbind(df.tmp, "landcover" = tmp$land_segments$segment_landcover)
        
        # extract canopy related values
        df.tmp = cbind(df.tmp, "cn_mean" = tmp$land_segments$canopy$h_mean_canopy)
        df.tmp = cbind(df.tmp, "cn_max"  = tmp$land_segments$canopy$h_max_canopy)
        df.tmp = cbind(df.tmp, "h_can"  = tmp$land_segments$canopy$h_canopy)
        df.tmp = cbind(df.tmp, "cn_med"  = tmp$land_segments$canopy$h_median_canopy)
        df.tmp = cbind(df.tmp, "cn_h_25" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[1,])
        df.tmp = cbind(df.tmp, "cn_h_50" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[2,])
        df.tmp = cbind(df.tmp, "cn_h_60" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[3,])
        df.tmp = cbind(df.tmp, "cn_h_70" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[4,])
        df.tmp = cbind(df.tmp, "cn_h_75" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[5,])
        df.tmp = cbind(df.tmp, "cn_h_80" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[6,])
        df.tmp = cbind(df.tmp, "cn_h_85" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[7,])
        df.tmp = cbind(df.tmp, "cn_h_90" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[8,])
        df.tmp = cbind(df.tmp, "cn_h_95" = unlist(tmp$land_segments$canopy$canopy_h_metrics)[9,])
        df.tmp = cbind(df.tmp, "cn_open" = tmp$land_segments$canopy$canopy_openness)
        df.tmp = cbind(df.tmp, "toc_rough" = tmp$land_segments$canopy$toc_roughness)
        df.tmp = cbind(df.tmp, "cn_unc" = tmp$land_segments$canopy$h_canopy_uncertainty)
        df.tmp = cbind(df.tmp, "cn_pho" = tmp$land_segments$canopy$n_ca_photons)
        df.tmp = cbind(df.tmp, "toc_pho" = tmp$land_segments$canopy$n_toc_photons)
        df.tmp = cbind(df.tmp, "cn_close" = tmp$land_segments$canopy$canopy_closure)
        df.tmp = cbind(df.tmp, "n_pho" = tmp$land_segments$canopy$n_photons)
        
        # add up canopy flags across the 5 sections of the canopy segment
        sub_cn_flag_sum = unlist(tmp$land_segments$canopy$subset_can_flag)[1,] + 
          unlist(tmp$land_segments$canopy$subset_can_flag)[2,] + 
          unlist(tmp$land_segments$canopy$subset_can_flag)[3,]+ 
          unlist(tmp$land_segments$canopy$subset_can_flag)[4,] + 
          unlist(tmp$land_segments$canopy$subset_can_flag)[5,]
        df.tmp = cbind(df.tmp, "sub_cn_flag_sum" = sub_cn_flag_sum)
        df.tmp = cbind(df.tmp, "ls_flag" = tmp$land_segments$canopy$landsat_flag)
        
        # Add Information Included in the Filename 
        df.tmp = as.data.frame(df.tmp)
        df.tmp = cbind(df.tmp, "beam" = beam)
        df.tmp = cbind(df.tmp, "filename" = filename)
        df.tmp = cbind(df.tmp, "year" = substr(filename, 7, 10))
        df.tmp = cbind(df.tmp, "month" = substr(filename, 11, 12))
        df.tmp = cbind(df.tmp, "day" = substr(filename, 13, 14))
        df.tmp = cbind(df.tmp, "hhmmss" = substr(filename, 15,20))
        df = rbind(df, df.tmp)
      }
    }
  }
  
  # Spatially subset the data 
  print(nrow(df))
  print("filtering for bounding box")
  df = df[which(df$lat>ymin & df$lat<ymax & df$lon>xmin & df$lon<xmax),]
  
  write.csv(df, output_path)
}