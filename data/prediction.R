# Load the randomForest library
require(randomForest)
 
# Get the parameters from the --args commandline (passed by the BASH script that
# calls this R script)
args <- commandArgs(trailingOnly=TRUE)

# Split the arguments to separate variables.
modelfile <- toString(args[1])
seg_csv   <- toString(args[2])
outlut_csv   <- toString(args[3])
seg_raster <- toString(args[4])
out_raster <- toString(args[5])

# Print the segment that is being processed
print(seg_csv)

# Load the model that was saved from ModelDevelopment.R
load(modelfile) # NOTE: the model object is called "rf"

# Get the segment data as csv file
segs <- read.csv(seg_csv, as.is=TRUE, stringsAsFactors=FALSE)

# Keep only segments where the segment_id is not zero (this is the segment of no
# data surrounding the image)
segs <- subset(segs, segs$segment_id != 0)

# Build a dataframe of the predictor stack variables from all of the segment 
#attributes. Force numeric in case R misreads the data type.
pred <- data.frame(as.numeric(segs$hh_mean), as.numeric(segs$hv_mean), as.numeric(segs$vcf_mean), as.numeric(segs$elev_mean))

# Assign names to the columns. These MUST match the names of the variables used
# to build the model in ModelDevelopment.R
names(pred) <- c('hh_mean', 'hv_mean', 'vcf_mean', 'elev_mean')

# Predict carbon for each segment.
predicted_carbon <- predict(rf,pred)

# Write the prediction out to a CSV file by building a dataframe and assigning
# column names to it.
out <- data.frame(segs$segment_id,round(predicted_carbon))
names(out) <- c("segid","pred")
options(scipen=10) # The number of digits before scientific notation (1e6) is used
write.csv(out,file=outlut_csv,row.names=FALSE,quote=FALSE)

######################
# Write Output Image #
######################

# Load the raster package
require(raster)

# Load the output segment raster 
img.out <- raster(seg_raster)

# Read the values of the segment raster as a vector
img <- getValues(img.out)

# Set the boundary segment to NA
img[img == 0] <- NA

# Create a new vector by replacing segment ids with the prediction
img.match <- as.integer(out$pred[match(img, out[,1])])

# Set the no data value for the output
img.match[is.na(img.match) == TRUE] <- 0 # Or some other value like -1

# Set the values of the output raster (reusing the segment raster object from above)
img.out <- setValues(img.out, img.match)

# Set the datatype to byte
dataType(img.out) <- 'INT1U'

# Write out the image (force datatype = Byte again.)
writeRaster(img.out, filename=out_raster, format="GTiff", options="COMPRESS=DEFLATE", datatype="INT1U", overwrite=T)
