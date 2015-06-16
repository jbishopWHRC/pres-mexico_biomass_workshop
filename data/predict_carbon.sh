#!/bin/bash

# This script takes an file and runs the carbon prediction
#
# AUTHOR: Jesse Bishop
# DATE: 2013-10-21
#

# Test the number of arguments provided to the script
if [ "$#" != "2" ]; then
    echo "USAGE ${0##*/} segment_csv code_directory"
    echo "EXAMPLE: ${0##*/} /mnt/t/code/project_repo/segments.csv /mnt/t/code/project_repo"
    echo
    exit
fi

# Read the arguments
seg_csv=$1
codedir=$2

# Get the directory containing the segments
segdir=$(dirname $seg_csv)

# Change to the directory where the code is stored
cd $codedir

# Specify the model data file (could also be an argument to the script)
modelfile="workshop_model.RData"

# Calculate some additional parameters based on the input
outlut_csv=$(echo $seg_csv | sed 's/.csv/_carbon.csv/g')
seg_tif=$(echo $seg_csv | sed 's/_predictors.csv/.tif/g')
out_tif=$(echo $outlut_csv | sed 's/.csv/.tif/g')

# Call the R script (prediction.R) to run the prediction
/usr/bin/R --vanilla --slave --args $modelfile $seg_csv $outlut_csv $seg_tif $out_tif < prediction.R

