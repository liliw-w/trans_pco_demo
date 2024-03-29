##############################################
########### Cluster genes to modules using WGCNA ###########
##############################################
# load packages -----
library(WGCNA)


# I/O & paras -----
if(interactive()){
  args <- scan(
    text = '
    result/ex.var.regressed.rds
    10
    result/coexp.module.rds
    result/Nmodule.txt
    ',
    what = 'character'
  )
} else{
  args <- commandArgs(trailingOnly = TRUE)
}

file.ex.var.regressed <- args[1]
minModuleSize <- as.numeric(args[2])


## output -----
file.coexp.module <- args[3]
file.nmodule <- args[4]


# read files -----
datExpr <- readRDS(file.ex.var.regressed)


# Run WGCNA -----
## Parameter specification -----
minModuleSize <- minModuleSize
MEDissThres <- 0.15
if_plot_adjacency_mat_parameter_selection <- FALSE
if_plot_only_tree <- FALSE
if_plot_color_and_tree <- FALSE
if_plot_eigengene_heatmap_tree <- FALSE
if_heatmap_of_network <- TRUE


## Step1: network construction -----
# determine the paramter in adjacency function: pickSoftThreshold() OR pickHardThreshold()
powers <- c(c(1:10), seq(from = 12, to=20, by=2))
sft <- pickSoftThreshold(datExpr, powerVector = powers, verbose = 5)
softPower <- sft$powerEstimate

## network construction
adjacency <- adjacency(datExpr, power = softPower)
TOM <- TOMsimilarity(adjacency)
dissTOM <- 1-TOM


## Step2: module detection -----
# tree construction using hierarchical clustering based on TOM
geneTree <- hclust(as.dist(dissTOM), method = "average")

# branch cutting using dynamic tree cut
dynamicMods <- cutreeDynamic(
  dendro = geneTree, distM = dissTOM,
  deepSplit = 4, pamRespectsDendro = FALSE,
  minClusterSize = minModuleSize
)
dynamicColors <- labels2colors(dynamicMods)

# eigene genes
MEList <- moduleEigengenes(datExpr, colors = dynamicColors)
MEs <- MEList$eigengenes

# Call an automatic merging function
merge <- mergeCloseModules(datExpr, dynamicColors, cutHeight = MEDissThres, verbose = 3)
mergedColors <- merge$colors
mergedMEs <- merge$newMEs

moduleLabels <- match(mergedColors, c("grey", standardColors(length(unique(mergedColors)))))-1
names(moduleLabels) <- colnames(datExpr)
tmp <- factor(moduleLabels, c(0, as.numeric(names(sort(table(moduleLabels)[-1], decreasing=T)))), 1:length(unique(moduleLabels))-1 )
moduleLabels <- as.numeric(levels(tmp))[tmp]; names(moduleLabels) = names(tmp)
Nmodule <- sum(as.numeric(names(table(moduleLabels))) != 0)

print(table(moduleLabels))
cat("Number of modules:", max(moduleLabels), "\n")

# Save results -----
result <- list(
  moduleColors = mergedColors,
  moduleLabels = moduleLabels,
  MEs = mergedMEs,
  old_moduleColors = dynamicColors,
  old_moduleLabels = dynamicMods,
  old_MEs = MEs,
  geneTree = geneTree
)
saveRDS(result, file = file.coexp.module)

write(Nmodule, file.nmodule)

