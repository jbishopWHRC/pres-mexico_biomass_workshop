#############################################################################
# The code below will pull the data from a database if you have that set up.
# Otherwise, use the read_csv function below.
#library(RPostgreSQL)
#con <- dbConnect(drv="PostgreSQL", host="database_host", user="database_user", dbname="database_name")
#query <- "SELECT z.folio, z.carbono_arboles_tpha, z.date_distance, z.measurement_date, o.id_vegetac AS veg_type_id, o.vegetacion AS veg_type, CASE WHEN o.vegetacion IN ('Bosque de abies', 'Bosque de ayarin', 'Bosque de cedro', 'Bosque de pino', 'Bosque de tascate') THEN 'CF' WHEN o.vegetacion IN ('Bosque de encino', 'Bosque de galerÝa') THEN 'BF' WHEN o.vegetacion IN ('Bosque de encino-pino', 'Bosque de pino-encino') THEN 'CBF' WHEN o.vegetacion = 'Manglar' THEN 'MG' WHEN o.vegetacion IN ('Bosque mesofilo de monta±a', 'Selva alta perennifolia', 'Selva alta subperennifolia', 'Selva baja perennifolia', 'Selva baja subperennifolia', 'Selva mediana subperennifolia') THEN 'THF' WHEN o.vegetacion IN ('Selva baja caducifolia', 'Selva baja espinosa', 'Selva baja subcaducifolia', 'Selva mediana caducifolia', 'Selva mediana subcaducifolia') THEN 'TDF' ELSE 'ERROR' END AS type_code, o.ecosistema AS ecosystem, AVG(s.num_pixels) AS num_pixels, AVG(s.num_masked_pixels) AS num_masked_pixels, AVG(s.elev_mean) AS elev_mean, AVG(s.slope_mean) AS slope_mean, AVG(s.vcf_mean) AS vcf_mean, AVG(hh_mean) AS hh_mean, AVG(hv_mean) AS hv_mean, AVG(lsmask_mean) AS lsmask_mean, MIN(lsmask_min) AS lsmask_min, MAX(lsmask_max) AS lsmask_max, COUNT(alos_id) AS num_images FROM (SELECT b.folio, SUM(b.carbono_arboles) / 0.1598925 AS carbono_arboles_tpha, y.date_distance, MIN(b.levantamiento_fecha_ejecucion) AS measurement_date  FROM (SELECT folio, CASE WHEN MIN(date_distance) + MAX(date_distance) = 0 THEN MIN(date_distance) WHEN MIN(date_distance) + MAX(date_distance) > 0 THEN MIN(date_distance) ELSE MAX(date_distance) END AS date_distance FROM (SELECT folio, days_from_alos AS date_distance, COUNT(sitio) AS plot_count FROM mexico_biomass_plots_filtered WHERE NOT carbono_arboles IS NULL AND NOT levantamiento_fecha_ejecucion IS NULL AND folio IN (SELECT folio FROM mexico_biomass_plots_old) AND NOT tipificacion IN ('Inaccesible (pendiente)', 'Inaccesible (social)', 'Vacio', 'Planeado') GROUP BY folio, days_from_alos HAVING COUNT(sitio) = 4 ORDER BY folio) AS x GROUP BY folio) AS y INNER JOIN mexico_biomass_plots_filtered b ON b.folio=y.folio AND b.days_from_alos=y.date_distance GROUP BY b.folio, y.date_distance) AS z INNER JOIN mexico_biomass_plots_old o ON z.folio=o.folio INNER JOIN mexico_biomass_plots_model_statistics s ON z.folio=s.folio GROUP BY z.folio, z.carbono_arboles_tpha, z.date_distance, z.measurement_date, o.id_vegetac, o.vegetacion, o.ecosistema;"
#d <- dbGetQuery(con, query)
#############################################################################


# Load the libraries necessary for this script
library(randomForest)
library(sampling)
# Set your working directory and read the training data csv
setwd('/Users/jbishop/Documents/Projects/858_MREDD/Workshops/201506_Biomass_CONAFOR/mexico_biomass_modeling')
d <- read.csv('workshop_training_data.csv')
dim[d]

# Plot at the relationships
plot(d$carbono_arboles_tpha, d$hv_mean)
plot(d$carbono_arboles_tpha, d$vcf_mean)

## Data Filtering
# Remove plots with steep slopes
sub <- subset(sub, slope_mean < 15) # degrees (or 15%)
dim(sub)[1]
# Remove plots with layover/shadow
sub <- subset(sub, lsmask_mean = 0)
dim(sub)[1]
# Remove plots with 0 carbon
sub <- subset(sub, carbono_arboles_tpha != 0)
dim(sub)[1]
# Remove plots where VCF data didn't cover the whole plot (cloud, shadow, water, etc)
sub <- subset(sub, sub$num_pixels == sub$num_masked_pixels)
dim(sub)[1]

# Take a look at the relationships
plot(sub$carbono_arboles_tpha, sub$hv_mean)
plot(sub$carbono_arboles_tpha, sub$vcf_mean)


## Remove the outliers by forest type for hv_mean and vcf_mean
# Create a vector to hold the folios that will be removed
f <- vector()

# Loop over each forest type, create an exponential model and calculate the 
# residuals. Then, remove any plots that are > 2 times the standard deviation.
# Generate plots to illustrate the filtering
for (i in unique(sub$type_code)){
    print(i)
    # Get the data for the current forest type
    s <- subset(sub, type_code == i)
    # Generate a polynomial model to fit the data.
    m.hv <- lm(s$hv_mean ~ poly(s$carbono_arboles_tpha, 3))
    # Predict the hv_mean using the model
    s$pred_hv_mean <- predict(m.hv, poly(s$carbono_arboles_tpha, 3))
    # Calculate the residuals from the model
    s$residual_hv <- resid(m.hv)
    # Calculate the standard deviation of the residuals
    hv.std_dev <- sd(s$residual_hv)
    # Add a column that indicates whether to remove the plot based on the 
    # standard deviation threshold
    s$remove_hv <- ifelse(s$residual_hv > 2 * hv.std_dev, TRUE, FALSE)
    # Plot the data, the prediction, and the remaining plots after filtering
    plot(s$carbono_arboles_tpha, s$hv_mean, main=i, pch=19, col='grey')
    points(s$carbono_arboles_tpha, s$pred_hv_mean, col='red')
    points(s$carbono_arboles_tpha[s$remove_hv != TRUE], s$hv_mean[s$remove_hv != TRUE], pch=21)

    # Do the same for Tree Cover
    m.vcf <- lm(s$vcf_mean ~ poly(s$carbono_arboles_tpha, 3))
    s$pred_vcf_mean <- predict(m.vcf, poly(s$carbono_arboles_tpha, 3))
    s$residual_vcf <- resid(m.vcf)
    vcf.std_dev <- sd(s$residual_vcf)
    s$remove_vcf <- ifelse(s$residual_vcf > 2 * vcf.std_dev, TRUE, FALSE)
    plot(s$carbono_arboles_tpha, s$vcf_mean, main=i, pch=19, col='grey')
    points(s$carbono_arboles_tpha, s$pred_vcf_mean, col='green')
    points(s$carbono_arboles_tpha[s$remove_vcf != TRUE], s$vcf_mean[s$remove_vcf != TRUE], pch=21)

    # Add the folios to be removed to the vector "f"
    f <- c(f, s$folio[s$remove_hv == TRUE | s$remove_vcf == TRUE])
}

# Subset the plots, keeping the plots that are not in the vector of plots to
# remove from the outlier analysis.
sub <- subset(sub, ! folio %in% f)
dim(sub)[1]

# Plot the cleaned data
plot(sub$carbono_arboles_tpha, sub$hv_mean)
plot(sub$carbono_arboles_tpha, sub$vcf_mean)

# Define carbon classes in 10 t/ha increments (rounding up to nearest 10)
sub$claseCarbona <- floor(sub$carbono_arboles_tpha / 10) * 10 + 10

# Now combine type_code and claseCarbona into one field for ease of stratification
sub$grp <- paste(sub$type_code, sub$claseCarbona, sep="_")

## Define a function that will help us generate stratified samples for testing and training
stratified = function(df, group, size) {
    #  USE: * Specify your data frame and grouping variable (as column 
    #         name) as the first two arguments.
    #       * Decide on your sample size. For a sample proportional to the
    #         population, enter "size" as a decimal. For an equal number 
    #         of samples from each group, enter "size" as a whole number.
    #
    #  Example 1: Sample 10% of each group from a data frame named "z",
    #             where the grouping variable column name is "nameGrpCol", use:
    # 
    #                 > stratified(z, "nameGrpCol", .1)
    #
    #  Example 2: Sample 5 observations from each group from a data frame
    #             named "z"; grouping variable column name is "nameGrpCol", use:
    #
    #                 > stratified(z, "nameGrpCol", 5)
    #
    require(sampling)
    
    # column # for group
    group <- which(names(df) %in% group, arr.ind = T)
    temp = df[order(df[group]),]
    # Calc # of samples per group
    if (size < 1) {
      nsamp = ceiling(table(temp[group]) * size)
    } else if (size >= 1) {
      nsamp = rep(size, times=length(table(temp[group])))
    }  
    # Select sample
    strat = strata(temp, stratanames = names(temp[group]), 
                   size = as.vector(nsamp), method = "srswor")
    (dsample = getdata(temp, strat))
}

# Order sub first, even though it's done in the stratified function
set.seed(5)
#sub.ord <- sub[order(sub$grp),]
sub.train <- stratified(sub, "grp", 0.8)
sub.val <- sub[(row.names(sub) %in% row.names(sub.train)) == FALSE,]

attach(sub.val)
val.stk <- data.frame(hh_mean, hv_mean, vcf_mean, elev_mean)
detach(sub.val)

attach(sub.train)
stack <- data.frame(hh_mean, hv_mean, vcf_mean, elev_mean)
rf <- randomForest(carbono_arboles_tpha ~ ., data=stack, ntree=200, xtest=val.stk, ytest=sub.val$carbono_arboles_tpha, importance = T, keep.forest = TRUE)
detach(sub.train)

save('rf', file='workshop_model_20150615.RData')

varImpPlot(rf, type=1)

# Some model evaluation
n.mod <- length(sub.train$carbono_arboles_tpha)
r2.mod <- round(1 - sum((sub.train$carbono_arboles_tpha - rf$predicted)^2)/sum((sub.train$carbono_arboles_tpha - mean(sub.train$carbono_arboles_tpha))^2), digits=2)
adj.r2.mod <- round(1 - (1 - r2.mod)*(n.mod - 1)/ (n.mod - ncol(stack) - 1), digits=2)
rmse.mod <- round(sqrt(sum((sub.train$carbono_arboles_tpha-rf$predicted)^2)/n.mod), digits=2)

# Same stats for validation data set
n.val <- length(sub.val$carbono_arboles_tpha)
r2.val <- round(1 - sum((sub.val$carbono_arboles_tpha - rf$test$predicted)^2)/sum((sub.val$carbono_arboles_tpha - mean(sub.val$carbono_arboles_tpha))^2), digits=2)
adj.r2.val <- round(1 - (1 - r2.val)*(n.val - 1)/ (n.val - ncol(val.stk) - 1), digits=2)
rmse.val <- round(sqrt(sum((sub.val$carbono_arboles_tpha-rf$test$predicted)^2)/n.val), digits=2)

