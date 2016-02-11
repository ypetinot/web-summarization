# TODO : how can I use the default location instead of specifying one ?	
local_r <- "~/R";  

args <- commandArgs(TRUE);
data_file <- args[1];

# Read values from tab-delimited file 
categories <- read.table(data_file, header=F, sep="\t")
category_names <- unique( categories$V1 );

#category_names

#png("odp-top-level-lcs-trends.png",width=9.0,height=12.0,units="cm",res=1200)
par(mfrow = c(3,5))  # 7 rows and 2 columns
for (i in category_names) {
#    hist( subset(categories, V1==i) , breaks = i, main = paste("method is", i, split = ""))
     categories.sub <- subset(categories, V1==i );
####     categories.sub <- subset(categories, V1==i && ( ! is.null(V3) ) && V3 >= 0 );
#    boxplot( categories.sub$V2 , categories.sub$V3 );
    boxplot( categories.sub$V3 ~ categories.sub$V2 , xlabel = "depth" );
    title( i );
    ###    hist(categories$i, main = paste("method is", i, split = ""))
}