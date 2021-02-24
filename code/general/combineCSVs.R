args = commandArgs(trailingOnly = T)
inDir = args[1]
outPath = args[2]

print(paste0("inDir: ", inDir))
print(paste0("outPath: ", outPath))

files  = list.files(inDir, full.names  = T)
combined = NULL
nfiles = length(files)

for(i in 1:nfiles){
    print(i)/nfiles
    tmp  = read.csv(files[i])
    if(is.null(combined)){
        combined = tmp
    }else{
        combined =  rbind(combined, tmp)
    }
}
write.csv(combined, outPath)