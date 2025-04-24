#!/bin/bash

for i in {1..22}; do
    plink --bfile "${BED}" --chr $i --make-bed --out "${OUTDIR%/}/chr_segments/chr_$i"
done