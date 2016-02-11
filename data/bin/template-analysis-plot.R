# TODO : how can I use the default location instead of specifying one ?	
local_r <- "~/R";  

#install.packages('reshape',local_r,repos="http://cran.us.r-project.org/");
#library('reshape',lib=local_r);

args <- commandArgs(TRUE);
data_file <- args[1];

# Read values from tab-delimited file 
categories <- read.table(data_file, header=T, sep="\t")

colnames(categories) <- gsub("[.]", "_", colnames(categories))
category_names <- colnames( categories )
category_names[[1]] <- NULL;

par(mfrow = c(3, 5))  # 7 rows and 2 columns
for (i in category_names) {
    ###    hist(categories$i, breaks = i, main = paste("method is", i, split = ""))
    ###    hist(categories$i, main = paste("method is", i, split = ""))
    plot( categories[,c("Level",i)] )
}
