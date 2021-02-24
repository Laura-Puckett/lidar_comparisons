#*********************************************************************************#
# -----0: Packages
# ********************************************************************************#

list.of.packages <- c("neonUtilities")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)>0) install.packages(new.packages, repos='http://cloud.r-project.org')

library(neonUtilities)

#*********************************************************************************#
# -----1: Inputs
# ********************************************************************************#
args = commandArgs(trailingOnly = T)
print(args)

source(args[1])

neonUtilities::byFileAOP(
  dpID = "DP1.30003.001",
  site = args[2],
  year = args[3],
  check.size = F,
  savepath = args[4])
