#*********************************************************************************#
# -----0: Packages
# ********************************************************************************#
library(dplyr); library(ggplot2)

#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#
setwd('/Volumes/cirrus/scratch/lkp58/lidar_comparisons/')

icesat2_data_path = './data/icesat2/3_comparison.csv'
gedi_data_path = './data/gedi/3_comparison.csv'
combined_data_path = './data/4_comparison_data.csv'
conus_groups_chart_path = '/Volumes/cirrus/scratch/lkp58/icesat_Sierras/supplementary_files/conus_forestgroup_chart.csv'

#*********************************************************************************#
# -----2: Parameters
# ********************************************************************************#
icesat2_strong_beams = c("1l","2l","3l")
GEDI_power_beams = paste0("BEAM", c("0101", "0110", "1000", "1011"))
n_groups = 3 # the number of forest groups to keep
can_uncert_threshold = 50

#*********************************************************************************#
# -----3: Filter Icesat2 Data
# ********************************************************************************#
icesat2_data_full = read.csv(icesat2_data_path, stringsAsFactors = F)
colnames(icesat2_data_full)

icesat2_filtered = icesat2_data_full %>%
  rename(
    night_flag = nght_fl) %>%
  mutate(sensor = "icesat2") %>%
  filter(night_flag == 1 &
           toc_pho > 0 &
           beam %in% icesat2_strong_beams) 

#*********************************************************************************#
# -----4: Filter GEDI Data
# ********************************************************************************#
gedi_data_full = read.csv(gedi_data_path, stringsAsFactors = F)
colnames(gedi_data_full)

gedi_filtered = gedi_data_full %>%
  mutate(sensor = "gedi") %>%
  mutate(night_flag = ifelse(solElev<0, 1, 0),
         beam = as.character(beam)) %>%
  filter(night_flag == 1 | beam %in% GEDI_power_beams)

#*********************************************************************************#
# -----4: Combine & Write Output File
# ********************************************************************************#
# need to reorder columns first

gedi_for_combined_df = gedi_filtered %>%
  rename(longitude = X,
         latitude = Y,
         sens_rh_100 = rh_100,
         sens_rh_98 = rh_98,
         sens_rh_95 = rh_95) %>%
  select(sens_rh_100, sens_rh_98, sens_rh_95,
         RH_100_ALS, RH_98_ALS, RH_95_ALS,
         ALS_all_grid, ALS_abvg_grid, ALS_grid_gauss, 
         cover, group_code, group_weight, sensor, longitude, latitude)

icesat2_for_combined_df = icesat2_filtered %>%
  rename(latitude = lat,
         longitude = lon,
         sens_rh_100 = cn_max,
         sens_rh_98 = h_can,
         sens_rh_95 = cn_h_95) %>%
  mutate(ALS_grid_gauss = NA) %>%
  select(sens_rh_100, sens_rh_98, sens_rh_95,
         RH_100_ALS, RH_98_ALS, RH_95_ALS,
         ALS_all_grid, ALS_abvg_grid, ALS_grid_gauss, 
         cover, group_code, group_weight, sensor, longitude, latitude)

data = rbind(icesat2_for_combined_df, gedi_for_combined_df)

conus_groups_chart = read.csv(conus_groups_chart_path)

data = data %>% 
  mutate(
    cover_coded = floor(cover/33.33),
    cover_class = ifelse(cover_coded == 0, "0-33%", cover_coded),
    cover_class = ifelse(cover_class == 1, "33-67%", cover_class),
    cover_class = ifelse(cover_class == 2, "67-100%", cover_class)) 

# conus_groups_chart generated from forestgroup values at: https://data.fs.usda.gov/geodata/rastergateway/forest_type/conus_forest_type_group_metadata.php
data = data %>%
  mutate(group_code = as.numeric(group_code)) %>%
  left_join(conus_groups_chart, by = "group_code")

# select groups with highest counts, filter for those
top_groups = data %>% filter(is.na(group)  == F) %>%
  group_by(group) %>%
  dplyr::summarize(count = n()) %>%
  arrange(desc(count)) %>%
  head(n_groups) %>%
  select(group) %>%
  mutate(group = as.character(group)) %>%
  as.list()
top_groups
data = data %>% filter(group %in% top_groups$group)

write.csv(data, combined_data_path)

#*********************************************************************************#
# -----5: Figures
# ********************************************************************************#
vars = c("ALS_abvg_grid",
         "ALS_all_grid",
         "ALS_grid_gauss",
         "RH_98_ALS",
         "RH_95_ALS")

pdf(paste0('./figures/ALS_methods_comoparison.pdf'))
for(var in vars){
  p = ggplot(data, aes(x = get(var), y = sens_rh_98))+
    geom_point(alpha = 0.1) +
    theme_bw() +
    coord_fixed(xlim = c(0,50), ylim = c(0,50)) +
    xlab(paste0("ALS Canopy Height [m], method: ", var)) +
    ylab("Satellite Canopy Height [m]")
  
  p = p + geom_smooth(method = "lm", formula = formula, se = FALSE, color = "blue") +
    ggpmisc::stat_poly_eq(aes(label =  paste(stat(eq.label), stat(adj.rr.label), sep = "~~~~")),
                          formula = y~x, parse = TRUE,
                          label.y = "top", label.x = "right")
  
  by_cover = p + 
    facet_grid(cols = vars(cover_class), rows = vars(sensor)) 
  print(by_cover)
  
  by_group = p + 
    facet_grid(cols = vars(group), rows = vars(sensor))
  print(by_group)
  
}
dev.off()


map = ggplot(data, aes(longitude, latitude)) +
  geom_point(aes(color = sensor), alpha = 0.1)

pdf('./figures/coverage.pdf')
print(map)
dev.off()
