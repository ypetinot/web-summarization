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

# paired t-test:
test_type="t-test";
result <- t.test(experiments_data$V1,experiments_data$V2,paired=TRUE);

#test_type="wilcoxon";
#p_value <- pvalue( wilcoxsign_test(experiments_data$V1 ~ experiments_data$V2 , zero.method="Wilcoxon", distribution="asympt") );

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
