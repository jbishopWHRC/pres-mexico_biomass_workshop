#!/bin/bash

# Josef Kellndorfer October 2013
# Script to mosaic files by path/row. 
# Near range over far range.
# Input are tilename and optional optfile with slected ids of classified PALSAR images
# using the ossim-mosaic -m FEATHER approach
# Algorithm:
# Make path mosaics from every scene covered by the bounding box. Then mosaic path near over far range
# with ossim

# TODO LIST
# TODO-JMK: Deal with Path/Row change at equator, e.g. via orbit

resample=average

# Buffer pixel for working mosaic 
bufpix=5

if [ $# -lt 6 ]
then
    echo
    echo WHIPS - Woods Hole Image Processing System
    echo Building Tiles via Mosaicking 
    echo
    echo Usage:
    echo $0 prod_level outpath tilename mosaic_option in_base_path optfile
    echo
    echo Use tilename format like tileX-70X0 for upper left corner \(e.g. long=-70,lat=0\) of output tile 
    echo 
    echo Mosaicking options are SIMPLE BLEND or FEATHER
    echo 
    echo
    echo Examples:
    echo $0 'ortho-dB-whrc-s0n' /mnt/p/tiles/10deg/s0n_2007_3arcsec tileX-70X0 SIMPLE /mnt/p/models/alos_glas_fheight/optfile_hhmin_america2.sorted
    echo $0 'ortho-dB-whrc-s0n-forestheight' /mnt/p/tiles/10deg/forest_height_18arcsec tileX-70X0 FEATHER /mnt/p/models/alos_glas_fheight/optfile_hhmin_america2.sorted
    echo
    exit 1
fi

##########################################################################################
# Process input parameters
prod_level=\'$1\'
outpath=${2%/}
tile=$3
tilesize=5
resolution=1arcsec
mosaic_option=$4
src_nodata=0
dst_nodata=0
inpath=$5
optfile=$6

echo $@

#Check for valid inputs
MOPTIONS="SIMPLE BLEND FEATHER"
if [[ $MOPTIONS == *${mosaic_option}* ]] 
then 
    echo Mosaic option: $mosaic_option 
else 
   echo Mosaic Option must be one of: $MOPTIONS
   exit 
fi



###########################################################################################
# Set outputname based on tilename, size, resolution
outtype=$(echo $1 | awk -F '-' '{ print $NF }')
outname=${outtype}_${tile}_${tilesize}deg_${resolution}.tif
outname_list=${outtype}_${tile}_${tilesize}deg_${resolution}_scenelist.csv

echo Prod_level: $prod_level
echo Result written to: 
echo ${outpath}/${outname}
# Clean existing files
if [ -f ${outpath}/${outname} ]
then
   echo Existing outfile needs to be deleted first. We Execute:
   echo /bin/rm ${outpath}/${outname}
   /bin/rm ${outpath}/${outname}
fi
if [ -f ${outpath}/${outname}.ovr ]
then 
   echo Existing pyramids needs to be deleted first. We Execute:
   echo /bin/rm ${outpath}/${outname}.ovr
   /bin/rm ${outpath}/${outname}.ovr
fi
echo


###########################################################################################
# Determine target resolution from input 
if [ "$resolution" == "100m" ]; then
    tr=0.000889111254866
elif [ "$resolution" == "50m" ]; then
    tr=0.000444555627433
elif [ "$resolution" == "15m" ]; then
    tr=0.000138888888900
elif [ "$resolution" == "1km" ]; then
    tr=0.00889111254866
# Acrseconds
elif [ "$resolution" == "0.5arcsec" ]; then
    tr=0.0001388888888888889
elif [ "$resolution" == "1arcsec" ]; then
    tr=0.0002777777777777778
elif [ "$resolution" == "2arcsec" ]; then
    tr=0.0005555555555555556
elif [ "$resolution" == "3arcsec" ]; then
    tr=0.0008333333333333333
elif [ "$resolution" == "6arcsec" ]; then
    tr=0.0016666666666666666
elif [ "$resolution" == "12arcsec" ]; then
    tr=0.003333333333333333
elif [ "$resolution" == "18arcsec" ]; then
    tr=0.005
elif [ "$resolution" == "24arcsec" ]; then
    tr=0.006666666666666666
elif [ "$resolution" == "36arcsec" ]; then
    tr=0.01
else
    tr=$resolution
fi

###########################################################################################
# Determine the extent of final tile
ulx=$(echo $tile | awk -F 'X' '{ print $2 }')
uly=$(echo $tile | awk -F 'X' '{ print $3 }')
lrx=$(echo "$ulx + $tilesize" | bc)
lry=$(echo "$uly - $tilesize" | bc)
# and the extent of the working tile with a buffer of bufpix pixels 
if [ "$ulx" == "-180" ]
then
    wulx=$ulx
else
    wulx=$(echo "$ulx - $bufpix * $tr" | bc)
fi
wuly=$(echo "$uly + $bufpix * $tr" | bc)
if [ "$lrx" == "180" ]
then
    wlrx=$lrx
else
    wlrx=$(echo "$lrx + $bufpix * $tr" | bc)
fi
wlry=$(echo "$lry - $bufpix * $tr" | bc)

echo Tile dimensions: $ulx $uly $lrx $lry
echo Working Tile dimensions: $wulx $wuly $wlrx $wlry
echo Buffer $bufpix Pixels. Target Resolution: $tr

###########################################################################################
# Generate a tempdir on ramdisk and switch to it
tempdirnam=$(basename $0)_${tile}_$(cat /dev/urandom | env LC_CTYPE=C tr -cd 'a-f0-9' | head -c 32)
temppath="/tmp"
tempdir=${temppath}/${tempdirnam}
/bin/mkdir $tempdir
cd $tempdir
function finish {
    /bin/rm -rf "$tempdir"
    #deactivate
}
trap finish EXIT
trap finish TERM


total_paths=$(cat ${optfile} | awk -F ',' '{print $1}' | sort -u | wc -l)
total_scenes=$(wc -l ${optfile} | awk -F ' ' '{print $1}')

############################################################################################
# Generate an empty output tile to mosaic into 
#Use the first found file as a dummy to determine number of bands for mosaicking
dummy=${inpath}/$(cat $optfile | head -1 | awk -F ',' '{ print $3 }')

if [ ! -f $dummy ]
then
    echo No valid input file found. No tile $tile produced.
    exit
fi

gdal_merge.py -o mosaic.tif  -ot Byte -ps $tr $tr -ul_lr $wulx $wuly $wlrx $wlry -init 0 -n $src_nodata -a_nodata $dst_nodata -createonly $dummy

# Determine all the paths we have to mosaic and loop over the paths 
paths_file=$(cat $optfile | awk -v OFS=',' -F ',' '{ print $1,$3 }')
scene_paths=$(cat $optfile | awk -F ',' '{ print $1 }' | uniq)
let p=0
let s=0
for sp in $scene_paths
do
    let p+=1
    echo "Working on Path $sp ($p of $total_paths)"
    gdal_merge.py -o imfile.tif -ot Byte -ps $tr $tr -ul_lr $wulx $wuly $wlrx $wlry -init 0 -n $src_nodata -a_nodata $dst_nodata -createonly $dummy
    allfiles=$(echo $paths_file | tr ' ' '\n' | grep "${sp}," | awk -F ',' '{ print $2 }')
    for i in $allfiles
    do
        let s+=1
        echo "Working on file $i ($s of $total_scenes)"
        if [ -f ${inpath}/$i ]
        then
            gdalwarp  -r $resample -tr $tr $tr ${inpath}/$i -srcnodata $src_nodata -dstnodata $dst_nodata tmp.tif
            gdalwarp  -srcnodata 0 -dstnodata 0 tmp.tif imfile.tif
          /bin/rm tmp.tif
        fi
    done
    # Now merge the entire path into the mosaic (using ossim for blending/feathering options)
    #/mnt/s/bin/whips_mosaic_feather.sh 
    if [[ $mosaic_option == "SIMPLE" ]]
    then
      gdalwarp  -srcnodata $src_nodata -dstnodata $dst_nodata imfile.tif mosaic.tif 
      #ossim-mosaic -m $mosaic_option imfile.tif mosaic.tif mosaic_new.tif 
      #/bin/mv mosaic_new.tif mosaic.tif
    else 
      ossim-mosaic -m $mosaic_option imfile.tif mosaic.tif mosaic_new.tif 
      /bin/mv mosaic_new.tif mosaic.tif
    fi
    /bin/rm imfile.tif
done

#Fix Area GTIFF Tag
gdal_edit.py -mo "AREA_OR_POINT=Area" mosaic.tif

#############################################################################################
# Write output
echo "Writing output file."
gdalwarp -co "COMPRESS=DEFLATE" -srcnodata $src_nodata -dstnodata $dst_nodata -r near -te $ulx $lry $lrx $uly -tr $tr $tr mosaic.tif ${outname} 
# Make overviews 
echo "Adding overviews."
gdaladdo -r average -ro ${outname} 2 4 8 16
# Write results to output directory
echo "Moving the files to $outpath."
/bin/cp ${outname} ${outname}.ovr ${outpath}
# Just to be on the save side in case trap is not working
cd /tmp
/bin/rm -rf "$tempdir"
echo Done. To inspect new file, execute:
echo
echo
