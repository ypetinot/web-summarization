args <- commandArgs(TRUE);
models_data_files <- c(args)

###x <- count.fields(models_data_files[1],sep="\t",comment.char="",quote="")
###print(x)

# Read values from tab-delimited autos.dat
models_data <- lapply( models_data_files , function(x) cbind( read.table(x, header=F, sep="\t", colClasses = "character", comment.char="",quote="") ) );

# Local install dir
# TODO : how can I use the default location instead of specifying one ?
local_r <- "~/R";

# Install stargazer locally (if needed)
install.packages("stargazer",local_r,repos="http://cran.us.r-project.org/");

# Load stargazer
library("stargazer",lib=local_r);

# Call to stargazer ?
stargazer(models_data, title="Regression Results")
#stargazer(models_data[1], models_data[2], title="Regression Results", align=FALSE, dep.var.labels=c("Overall Rating","High Rating"), covariate.labels=c("H","No Special Privileges", "Opportunity to Learn","Performance-Based Raises","Too Critical","Advancement"), omit.stat=c("LL","ser","f"), no.space=TRUE)

quit();

# normality test
#normality_1=shapiro.test(experiments_data$V1);
#normality_2=shapiro.test(experiments_data$V2); 

# Start with a normality test
if ( normality_1["p.value"] < 0.05 || normality_2["p.value"] < 0.05 ) {

   #if at least one of the columns is not normally distributed, use a non-parametric "paired" test
   #if the p<0.05 there is a significant differences.

   print("One of the variables is not normally distributed, will use Wilcox test ...");
   result <- wilcox.test(experiments_data$V1,experiments_data$V2, paired=TRUE);
   p_value <- result["p.value"];

} else {

   #if p-value < 0.05 then the data are NOT normally distributed.
   #test the second var:  L$V1
   
   print("Both variables are normally distributed, will use Student test ...");

   # paired t-test:
   result <- t.test(experiments_data$V1,experiments_data$V2,paired=TRUE);
   p_value <- result["p.value"];

}

if ( p_value < 0.05 ) {
   print("significant");
} else {
  print("non-significant");
}
