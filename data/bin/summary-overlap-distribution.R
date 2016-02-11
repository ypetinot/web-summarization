library(Rlab);

args <- commandArgs(TRUE);
data_file <- args[1];

# Read values from tab-delimited autos.dat
# TODO : the quote parameter does NOT make sense ...
data <- read.table(data_file, header=F, sep="\t", comment.char="");

#prob.class <- cut(data$V4, c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1), include.lowest = TRUE)
#prob.mag <- tapply(data$V4, prob.class, mean)
#plot(prob.mag, type = "l", xlab = "extractive probability")

# CURRENT : p_abstractive = 1 - p_extractive ?
# CURRENT : how do we factor in p_function ?

#with(dfr[(dfr$var3 < 155) & (dfr$var4 > 27),],
#with(data[(data$V4 > 0.5),], plot(data$V2, data$V4, type = "h", col = "red", xlim=c(0,8000)));
#with(data[data$V4 < 0.5,], plot(V4 ~ V2, type = "h", col = "red", xlim=c(0,8000)));
###with(data[data$V4 < 0.5,], plot(V4 ~ V2, type = "h", col = "red"));
###with(data[data$V4 >= 0.5,], plot(V4 ~ V2, type = "h", col = "red"));
###with(data[data$V2<1000000,], plot(V4 ~ V2, type = "h", col = "red"));

####with(data[], boxplot(V15 ~ V2, type = "h", col = "red", ylab="chi-square", xlim=c(0,50000), ylim=c(0,20), vertical=TRUE));
bplot.xy(data$V2, data$V15, N = 10);

#, breaks = pretty(x, N, eps.correct = 1),
#         style = "tukey", outlier = TRUE, plot = TRUE, xaxt =
#         "s", ...)

###with(data[data$V2<1000,], plot(V15 ~ V2, type = "h", col = "red", ylab="chi-square"));
###with(data, plot(V15 ~ V2, type = "h", col = "red", ylab="chi-square"));
#with(data[data$V2<10000,], plot(V4 ~ V2, type = "h", col = "red", ylab="content co-occurrence"));
#with(data[data$V2<10000,], plot(V6 ~ V2, type = "h", col = "red", ylab="title co-occurrence"));
#with(data[data$V2<10000,], plot(V8 ~ V2, type = "h", col = "red", ylab="url co-occurrence"));
#with(data[data$V2<10000,], plot(V10 ~ V2, type = "h", col = "red", ylab="all modalities co-occurrence"));

#hist( data$V4 );