#!/bin/bash
infile=$1
inscript=$2
for i in $(cat $infile)
do
    $inscript $i
done