args <- commandArgs(TRUE);
data_file <- args[1];

# Read values from tab-delimited autos.dat 
experiments_data <- read.table(data_file, header=F, sep="\t")

# normality test
###normality_1=shapiro.test(experiments_data$V1);
###normality_2=shapiro.test(experiments_data$V2); 

# TODO : how can I use the default location instead of specifying one ?	
local_r <- "~/R";  

##install.packages("coin",local_r,repos="http://cran.us.r-project.org/");
library("coin",lib=local_r);
library("coin");

# Start with a normality test
###if ( normality_1["p.value"] < 0.05 || normality_2["p.value"] < 0.05 ) {

   #if at least one of the columns is not normally distributed, use a non-parametric "paired" test
   #if the p<0.05 there is a significant differences.

   write("One of the variables is not normally distributed, will use Wilcox test ...",stderr());
   test_type="wilcoxon";

   ###result <- wilcox.test(experiments_data$V1,experiments_data$V2, paired=TRUE);
   # Note : adding exact=FALSE so that it proceeds even in the presence of ties
   # https://stat.ethz.ch/pipermail/r-help/2011-April/274931.html
   # https://stat.ethz.ch/pipermail/r-help/2011-April/274932.html (also worth reading)  
   ###result <- wilcox.test(experiments_data$V1,experiments_data$V2, paired=TRUE, exact=FALSE);
   # Note : still failing, trying without the continuity correction
   ###result <- wilcox.test(experiments_data$V1,experiments_data$V2, paired=TRUE, exact=FALSE, correct=FALSE);

   # Note : still failing, trying with a different package (exactRankTests)
   ###install.packages("exactRankTests",local_r,repos="http://cran.us.r-project.org/");
   ###library("exactRankTests",lib=local_r);
   # Note : currently fails and library apparently no longer under development --> giving up for now
   ###result <- wilcox.exact(experiments_data$V1,experiments_data$V2, paired=TRUE);

   ###p_value <- result["p.value"];				      

   # Note : trying a different package (coin)
   p_value <- pvalue( wilcoxsign_test(experiments_data$V1 ~ experiments_data$V2 , zero.method="Pratt", distribution="asympt") );
   ###   p_value <- pvalue(wilcoxsign_test(experiments_data$V1 ~ experiments_data$V2 , zero.method="Wilcoxon", distribution="asympt") );

###} else {

###   #if p-value < 0.05 then the data are NOT normally distributed.
###   #test the second var:  L$V1
   
###   write("Both variables are normally distributed, will use Student test ...",stderr());
###   test_type="t-test":

###   # paired t-test:
###   result <- t.test(experiments_data$V1,experiments_data$V2,paired=TRUE);
###   p_value <- result["p.value"];

###}

if ( is.numeric( p_value ) ) {

   if ( p_value < 0.05 ) {
      result = "significant";
   } else {
      result = "non-significant";
   };

} else {

   result = "n/a";

}

paste( result , test_type , p_value , collapse = " " );
